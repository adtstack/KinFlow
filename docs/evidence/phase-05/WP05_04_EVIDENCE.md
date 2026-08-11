# Phase 05 WP05-04 Android Mobile Push Evidence

- Work Package: WP05-04 — Android FCM provider delivery, permission UX, foreground presentation, background/terminated continuation, tap reauthorization
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 WP02-06/WP03/WP04/Phase 05 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter SDK 3.44.7 stable, Dart 3.12.2, Node 24.15.0, npm 11.12.1, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP05-04 LOCAL AUTOMATED PASS / HOSTED·PROVIDER·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-04 / FR-NOTIF-001 / FR-FLT-007 | PASS FOR LOCAL ANDROID UX / OVERALL PARTIAL | 시작 시 system prompt를 요청하지 않고 알림 센터의 명시적 action 뒤에만 permission을 요청한다. denied는 endpoint proof purge, 설정 이동과 durable inbox fallback을 제공한다. 실제 Android system UI/TalkBack은 남았다. |
| WP05-04 / FR-NOTIF-002 / D-049 | PASS FOR SYNTHETIC FCM TOKEN LIFECYCLE / OVERALL PARTIAL | authorized+active household+token일 때만 기존 encrypted endpoint lifecycle에 bind한다. token rotation, 같은 household 내 member/account 전환 재등록, permission denial과 logout purge를 자동 검증했다. 실제 Firebase token/device는 남았다. |
| WP05-04 / FR-NOTIF-003 / D-022 / D-023 | PASS FOR LOCAL CHORE PUSH PIPELINE / OVERALL PARTIAL | source event를 inbox와 독립적으로 latest state/current preference/quiet hours/membership/endpoint로 재평가하고 server worker가 due delivery를 claim한다. Calendar reminder와 hosted schedule은 남았다. |
| WP05-04 / FR-NOTIF-005 | PASS FOR LOCAL SAFE CONTINUATION / OVERALL PARTIAL | foreground/background/terminated/local payload를 strict parse하고 auth+active household 이후 recipient membership/latest state/exact routing RPC를 통과할 때만 Today로 이동한다. 실패·stale·mismatch는 알림 센터로 fail closed한다. 실제 device tap은 남았다. |
| WP05-04 / FR-NOTIF-006 / NFR-REL-01 | PASS FOR LOCAL BOUNDED DELIVERY / OVERALL PARTIAL | `(source_event_id, endpoint_id)` identity, skip-locked lease, 최대 5회, exact finalize replay, stale lease/fingerprint 방어, receipt hash와 invalid-token guarded revoke를 구현했다. provider accepted 뒤 DB completion 유실의 고급 reconciliation은 WP05-05다. |
| NFR-SEC-01 / NFR-SEC-02 / NFR-PRIV-01 | PASS FOR NEW SURFACE | private delivery tables와 service-only mediated claim/finalize, dedicated worker secret, versioned AES keyring, Firebase service account server boundary, exact minimal payload, generic localized copy와 aggregate-only response를 검증했다. |
| NFR-COMP-01 / D-002 / D-021 | PASS FOR LOCAL ADDITIVE ANDROID SLICE / OVERALL PARTIAL | Firebase public options는 optional all-or-none이며 비구성·비Android는 unavailable adapter로 격리한다. additive migration과 Android debug build가 기존 회귀를 유지한다. remote N-1과 iOS/APNs는 남았다. |

## Database Contract

- `app_private.notification_push_evaluations`는 source event당 native-push outcome을 durable inbox와 독립적으로 확정한다. 따라서 `in_app=false/native_push=true`도 전송 가능하고 inbox item은 nullable reference다.
- `app_private.notification_push_deliveries`는 `(source_event_id, endpoint_id)`를 유일 identity로 사용한다. `pending|leased|retry_wait|succeeded|failed|cancelled`, 최대 5회, opaque lease와 exact completion material을 보존한다.
- claim은 source event의 최신 occurrence/recipient, 현재 native-push preference, IANA timezone quiet hours와 active granted Android endpoint를 다시 검사한다. stale preference/state/endpoint는 provider 호출 전에 취소한다.
- provider success receipt 원문은 저장하지 않고 SHA-256 digest 32 bytes만 저장한다. permanent invalid-token 결과는 전송 당시 fingerprint가 endpoint의 현재 fingerprint와 같을 때만 revoke한다.
- `resolve_notification_push_target`은 authenticated exact recipient, active household membership, payload routing, latest source state와 optional uncancelled inbox link를 재확인하고 allowlisted `today`만 반환한다.
- claim/finalize/pause는 `service_role` mediated execute만 허용하고 private tables direct privilege는 없다. target resolver만 `authenticated`에 허용한다.
- `set_notification_push_worker_paused(..., ROLLBACK_DISABLED, ...)`는 새 claim을 막고 active pending/leased/retry delivery를 stable rollback code로 취소한다.

## Edge and Provider Contract

- `notification-push-worker`는 body/query 없는 POST와 dedicated exact Bearer secret만 받는다. gateway JWT verification은 끄되 함수 내부 worker authentication을 필수로 한다.
- claim DTO는 exact key/UUID/base64/locale/attempt/lease parser를 통과해야 한다. endpoint ciphertext는 version별 canonical 32-byte AES keyring으로 worker memory에서만 AES-256-GCM open한다.
- Firebase service-account JSON은 필요한 project/email/private-key field만 취하고 RS256 one-hour assertion으로 messaging scope OAuth token을 발급한다. access token은 만료 60초 전까지만 memory cache한다.
- FCM HTTP v1 request는 exact project endpoint, restricted Android package, one-hour TTL, high priority, generic Android localization keys와 최소 routing identifier만 포함한다.
- accepted provider message name은 hash 후 finalize한다. quota/unavailable/internal/timeout은 bounded retry, unregistered/invalid argument는 guarded endpoint revoke, auth/sender/decrypt failure는 permanent result로 변환한다.
- provider body, credential, token, ciphertext, fingerprint, receipt 원문이나 exception detail은 Edge response/error에 반사하지 않는다. 외부 응답은 aggregate count만 반환한다.

## Flutter and Android Lifecycle

- Firebase background callback은 top-level `@pragma('vm:entry-point')`이며 `runApp` 전에 등록된다. callback은 exact envelope parse만 수행하고 UI/state mutation이나 scheduling authority를 갖지 않는다.
- Android Firebase public identifiers 네 개가 모두 유효할 때만 Firebase Messaging과 local presenter를 compose한다. missing/partial/invalid/non-Android/init failure는 durable inbox가 유지되는 unavailable state다.
- startup은 현재 permission만 읽고 prompt/token registration을 시작하지 않는다. 알림 센터 pre-prompt action이 permission 요청을 시작하며 denial은 설정 이동과 proof-based endpoint purge로 이어진다.
- authorized 상태에서 token/current household/member/locale/timezone/runtime metadata를 bind하고 `onTokenRefresh`를 serialize한다. 같은 household라도 member가 바뀌면 이전 in-memory binding을 재사용하지 않고 재등록한다.
- foreground remote message는 generic localized local notification으로 한 번만 표시한다. remote/local tap과 initial message는 auth와 active household 준비까지 보류한 뒤 server target authorization을 거친다.
- Android는 localized high-importance `kinflow_reminders` channel, private visibility, monochrome status icon, default FCM channel/icon과 app notification settings method channel을 제공한다.
- APK permission allowlist는 `INTERNET`, `POST_NOTIFICATIONS`, `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `VIBRATE`, biometric, FCM receive와 package-scoped dynamic receiver다. 위치·연락처·광고 ID·광범위 storage permission은 없다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS, ordered 28 migrations including `20260808040000_notification_push_delivery.sql` and synthetic seed |
| focused notification push pgTAP | PASS, 48/48 |
| full database regression | PASS, 33 files / 1,859 pgTAP tests |
| database lint | PASS, warning level with fail-on-error; schema error 0 |
| focused push Edge/runtime contract | PASS, 17/17 |
| repository JavaScript contract suite | PASS, 93/93 |
| focused Flutter push lifecycle | PASS, coordinator 9/9 plus strict parser/repository/data source/widget/config/security fixtures |
| full Flutter regression | PASS, 514 tests + local-connectivity opt-in 1 skip |
| full Flutter coverage | PASS, 11,888/15,183 lines, 78.30% |
| exact formatter/analyzer | PASS, 318 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| public config/secret/codegen | PASS, exact public allowlist; all server-only notification keys scanned; high-confidence secret 0; generated drift 0/8 files |
| dependency/license/vulnerability | PASS, 165 Pub + 15 npm license audit; fixed-version offline OSV scan PASS |
| workflow/supply-chain contract | PASS, 5 jobs, 17 pinned action uses, `contents:read`; actionlint PASS |
| OpenAPI and matrix structure | PASS, OpenAPI 3.1 parses with 18 paths/31 schemas; requirements 116×18, tests 61×11, risks 30×15, release 23×10, platform 20×12 |
| Android dev APK gate | PASS, 218,210,635 bytes, SHA-256 `1b3238906345f8fb5f1c906dbcb181238a0073c92b53305eab72f816863c6117`; package/API/backup/App Link/provenance/permission allowlist verified |
| whitespace | PASS, final `git diff --check` output 0 |

Focused DB fixtures cover private schema/check/index/FK/grant boundaries, inbox-independent native-push evaluation, disabled/stale/no-endpoint outcomes, quiet-hour delay, concurrent claim, expired lease, exact success/retry/permanent replay, stale lease/fingerprint rejection, hashed receipt, current-token invalidation, pause/cancel and recipient target isolation.

Edge fixtures cover scheduler auth, exact empty POST surface, bounded claim/finalize DTOs, AES keyring/version/AAD, service-account parsing, RS256 assertion, OAuth cache/failure, exact FCM localization/minimal data, documented result mapping, receipt hashing and non-reflection.

Flutter fixtures cover no startup prompt, explicit grant, denial/settings/purge, token failure/rotation, same-household member switch, foreground dedupe, remote/local initial tap, auth/household wait, target allow/deny, startup-denied deferred purge without repeated purge, background registration order, optional Firebase configuration and server-secret rejection.

## Files and Migration

- Migration/test: `supabase/migrations/20260808040000_notification_push_delivery.sql`, `supabase/tests/database/notification_push_delivery.test.sql`
- Edge contract/runtime: `supabase/functions/_shared/notification_push_contract.mjs`, `notification_push_runtime.mjs`
- Edge entry/config/test: `supabase/functions/notification-push-worker/`, `supabase/config.toml`, `scripts/ci/notification-push-contract.test.mjs`
- Flutter domain/application: push models, gateway/presenter ports, coordinator and repository target resolver under `apps/kinflow_app/lib/features/notifications/`
- Flutter infrastructure/composition: `apps/kinflow_app/lib/infrastructure/firebase/`, Supabase notification data source, auth dependencies/bootstrap/providers and global lifecycle host
- Android/config: manifest, `MainActivity.kt`, notification icon/resources, Gradle desugaring, public config/schema/examples, `scripts/ci/android-public-config.mjs`, `scripts/ci/android-build.sh`
- UX/tests: notification-center pre-prompt/status/settings UI, en/ko/en-XA ARB/generated l10n, push coordinator/model/repository/data source/widget/config/security tests
- Contracts/governance: `notification-push.yaml.md`, notification endpoint/inbox/worker, OpenAPI/database/RLS/env contracts, Phase 05, consolidated specs, requirement/test/platform/risk/release matrices and `WP05_04_WORKPLAN.md`

## Security, Privacy, and Data Impact

- raw FCM token은 기존 endpoint registration network boundary와 push worker의 one-send memory 밖에 평문으로 남지 않는다. Flutter persistent state에는 proof/metadata만 있고 DB token은 versioned AES-GCM envelope다.
- Firebase service account, scheduler secret, token encryption/decryption keys와 service-role key는 public config exact allowlist에 없고 explicit server-only/secret scanner 목록에 있다.
- push evaluation/delivery/control은 private schema이며 direct client/service table access가 없다. tap payload는 capability가 아니고 server-authenticated latest-state lookup을 다시 수행한다.
- FCM data에는 family content가 없고 visible copy는 앱 resource의 generic 문구다. receipt 원문과 provider response는 보존하지 않는다.
- 새 Android permission은 notification transport/presentation과 기존 biometric 범위뿐이며 위치·연락처·광고 ID·사진/파일 접근을 추가하지 않는다.
- 자동 검증은 synthetic UUID/token/service-account key와 fake provider/local Supabase만 사용했다. production credential·고객 계정·가족 데이터는 사용하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google/Firebase 계정, production/staging Firebase project, service-account secret injection, remote Supabase migration/Edge deployment와 hosted scheduler는 **NOT RUN**이다.
- physical Android의 permission not-determined/denied/authorized/settings recovery, foreground/background/terminated FCM receive, notification shade/local tap, token rotation과 OEM battery policy matrix는 **NOT RUN**이다.
- 실제 삭제된 occurrence, removed member, account/household switch와 provider-invalid token delivery를 사용한 remote/device 시나리오는 **NOT RUN**이다.
- signed AAB, Play internal track와 production Firebase delivery metrics/log non-leakage 검증은 release Gate다.
- iOS/APNs는 D-021의 Android Store MVP 범위 밖이며 별도 ADR 전에는 구현·완료로 주장하지 않는다.

## Remaining Risks and Completion Boundary

1. FCM이 accepted를 반환한 뒤 DB finalize가 유실되면 lease expiry 후 중복 submit 가능성이 남는다. provider receipt query가 없는 FCM 특성을 고려한 ambiguity window/dedupe 정책은 WP05-05에서 결정한다.
2. hosted scheduler cadence, queue/provider SLO, quota/outage exponential policy, alert/dashboard와 incident drill은 아직 없다.
3. `no_endpoint` 평가를 terminal로 두어 사용자가 due 시각 뒤 permission을 켜도 과거 reminder를 소급 발송하지 않는다. stale-window 제품 정책은 WP05-05에서 재검토한다.
4. versioned decrypt keyring과 service-account rotation은 코드 계약만 있으며 secret manager 배포·old-key retirement rehearsal이 필요하다.
5. Android OS/OEM가 notification+data payload와 terminated tap을 실제로 전달하는 동작은 자동화만으로 증명하지 않았다.
6. 기존 `sentry_flutter`가 Kotlin Gradle Plugin을 적용한다는 Flutter future-compatibility build warning이 남아 있다. 이번 Firebase slice에서 새 warning을 유발한 것은 아니지만 Phase 08 toolchain review가 필요하다.
7. Phase 05 전체와 FR-NOTIF/T-PUSH 상위 Gate는 WP05-05 reliability, WP05-06 offline/read cache와 remote/device validation이 남아 `PARTIAL`이다.

WP05-04 자체는 synthetic/fake provider를 사용한 local automated Android vertical slice로 완료했다. 상위 기능 목표는 계속 active다.

## Rollback

- Firebase public client options 네 개를 모두 비우면 앱은 unavailable adapter로 돌아가고 durable inbox는 유지된다.
- `notification-push-worker` scheduler/invocation을 중지하거나 `set_notification_push_worker_paused(true, 'ROLLBACK_DISABLED', ...)`를 호출하면 새 delivery를 차단·취소한다.
- production 적용 전에는 migration, Edge worker/config, Flutter Firebase/local adapters/dependencies, Android manifest/resources와 tests/contracts를 함께 revert한다.
- production 적용 후 applied migration을 수정·삭제하지 않는다. forward migration으로 claim/finalize execute를 revoke하고 pending delivery를 stable rollback code로 종결한다.
- endpoint ciphertext를 보존하는 동안 해당 token key version을 decrypt keyring에서 제거하지 않는다. credential/key rotation은 active endpoint refresh와 retention 확인 뒤 수행한다.

## Next Entry Condition

- 다음 기능 우선순위는 Phase 05 WP05-05 reliability다.
- provider accepted/completion-loss ambiguity, outage/quota backoff, stale window, queue/provider health aggregate와 pause/replay runbook을 DB/Edge fake provider로 먼저 고정한다.
- 실제 Firebase project·실계정·실기기 검증은 사용자 지시에 따라 대부분의 기능 개발 이후 마지막 Gate에 유지한다.
