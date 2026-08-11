# Phase 05 WP05-03 Device Registration Evidence

- Work Package: WP05-03 — secure installation identity, encrypted native-push token binding, rotation/replay, proof revoke, member-removal and provider-invalid cleanup
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 WP02-06/WP03/WP04/Phase 05 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2, Node 24.15.0, npm 11.12.1, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP05-03 LOCAL AUTOMATED PASS / PROVIDER·HOSTED·REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-03 / FR-NOTIF-002 | PASS FOR SYNTHETIC TOKEN LIFECYCLE / OVERALL PARTIAL | environment별 installation UUID, user/household/member binding, AES-256-GCM token envelope, fingerprint dedupe, rotation, response-loss replay와 logout/account-switch/member-removal revoke를 구현했다. 실제 FCM/APNs token과 device는 남았다. |
| API-021 | PASS FOR LOCAL REGISTRATION CONTRACT | verified user, active membership, registration UUID, expected version과 exact request를 server-side에서 검증한다. initial register, metadata refresh, token rotation, exact replay, conflict와 cross-account reassignment를 구분한다. |
| API-022 / D-049 | PASS FOR LOCAL PURGE CONTRACT | 256-bit account-bound proof로 sign-out 후에도 endpoint를 멱등 해지한다. Flutter auth purge는 active 및 uncertain pending proof를 원격 해지한 뒤 계정 binding만 제거하며 installation UUID는 유지한다. |
| T-PUSH-05 | PASS FOR LOCAL DB/EDGE/FLUTTER SLICE / OVERALL PARTIAL | synthetic token rotation, token reassignment, response-loss recovery, stale/current fingerprint invalidation과 member removal을 자동 검증했다. 실제 provider invalid-token receipt는 남았다. |
| NFR-SEC-01 / NFR-SEC-02 | PASS FOR NEW SURFACE | token material table과 private audit의 client/direct-service 접근을 거부한다. service key와 encryption key는 Edge environment에만 있고 auth/notification secure-storage namespace를 분리했다. |
| NFR-PRIV-01 | PASS FOR NEW SURFACE | raw token, secret, ciphertext, fingerprint, provider detail과 identity display data가 response, audit, error, Flutter state 또는 public configuration에 들어가지 않는다. |
| NFR-REL-01 / NFR-COMP-01 | PASS FOR LOCAL ADDITIVE SLICE / OVERALL PARTIAL | registration/revoke/invalidation replay와 stale-result guard를 검증했다. additive migration과 optional lifecycle provider가 기존 auth, inbox, Chore와 Calendar 회귀를 유지한다. remote N-1 rehearsal은 남았다. |

## Database Contract

- `public.notification_endpoints`는 `(auth_user_id, installation_id, channel)` binding, household/member composite integrity, sealed token/key version/fingerprint, one-way revocation-secret hash, permission/runtime metadata와 lifecycle version을 저장한다.
- active `(channel, token_fingerprint)`는 한 건만 허용한다. 같은 token이 다른 계정에 등록되면 기존 binding을 `token_reassigned`로 먼저 revoke하고 새 binding을 활성화한다.
- `get_notification_endpoint_status`만 authenticated metadata 조회를 허용한다. table direct read/write와 raw token material은 `anon`, `authenticated`, direct `service_role` 모두 접근할 수 없다.
- `upsert_notification_endpoint`는 service role 전용이며 verified auth UID를 active household member에 다시 bind한다. 동일 registration UUID와 동일 material replay는 version/audit을 늘리지 않고, 다른 material 재사용은 거부한다.
- `revoke_notification_endpoint_by_secret`는 installation/channel/registration/secret-hash가 일치할 때만 revoke하고, 존재 여부와 관계없이 상위 Edge가 같은 성공 응답을 반환할 수 있게 0 또는 1만 반환한다.
- `invalidate_notification_endpoint`는 endpoint ID와 현재 fingerprint가 함께 일치할 때만 provider reason으로 revoke한다. 회전 전 token의 늦은 provider failure는 새 token을 끄지 못한다.
- active member 제거 trigger는 같은 transaction에서 해당 household endpoint를 `membership_removed`로 revoke한다.
- `app_private.notification_endpoint_events`는 `registered|refreshed|rotated|revoked`, allowlisted reason, endpoint version과 timestamp만 immutable하게 보존한다.

## Edge Function Contract

- `notification-endpoint` POST는 Supabase gateway JWT 검사를 함수 내부 GoTrue `/auth/v1/user` 검증으로 대체한다. UUID `idempotency-key`, exact JSON body, no query, 16 KiB body cap과 exact CORS origin을 요구한다.
- raw provider token은 Edge memory에서 12-byte random nonce와 version-bound AAD를 사용한 AES-256-GCM으로 seal한다. token fingerprint와 revocation-secret hash는 canonical SHA-256 standard base64다.
- encryption key는 canonical standard base64의 정확히 32 bytes여야 하고 positive key version을 별도 환경변수로 요구한다. weak/non-canonical key와 잘못된 version은 startup boundary에서 거부한다.
- POST가 RPC에 전달하는 값은 ciphertext, fingerprint, secret hash와 metadata뿐이다. 응답은 endpoint metadata와 request/contract version만 포함한다.
- DELETE는 live JWT 없이 UUID installation/registration, `native_push` channel과 unpadded base64url 43자의 proof를 요구한다. endpoint가 없거나 이미 해지된 경우에도 `{revoked: true}`만 반환한다.
- SQLSTATE는 stable content-free error code로만 변환하고 provider/RPC response body, credential, token material 또는 exception detail을 반사하지 않는다.

## Flutter Lifecycle

- installation UUID는 notification 전용 secure namespace에 environment별로 한 번 생성해 계정 전환과 logout 뒤에도 유지한다. active/pending proof는 auth user에 bind해 별도 저장한다.
- Android secure storage encrypted-shared-preferences namespace와 iOS Keychain `accountName`은 각각 `kinflow_notification_<environment>_v1`이며 auth namespace와 분리된다.
- raw provider token은 registration intent와 network 호출 동안만 memory에 존재한다. pending record에는 installation/registration UUID, secret proof와 metadata만 network 전에 먼저 기록한다.
- 성공 응답은 pending을 active binding으로 승격한다. 응답 유실 후 status의 `lastRegistrationId`가 pending registration과 같으면 현재 callback token으로 같은 registration을 exact replay한다. 같은 token이면 version/audit 증가 없이 승격하고, 그 사이 token이 바뀌었으면 멱등 충돌을 확인한 뒤 새 proof로 한 번 회전한다.
- version conflict 또는 idempotency conflict는 remote status를 확인하고, 진짜 충돌이면 새 proof/registration UUID로 최대 한 번만 회전한다.
- logout, account switch, session expiry/revoke purge는 active와 uncertain pending proof를 serialize해 해지한다. remote revoke 실패 시 proof를 보존하고 auth local purge를 fail-closed해 재시도 가능성을 유지한다.
- production endpoint repository/lifecycle은 composition에 연결했지만 provider token source는 아직 연결하지 않아 실제 token 없이 자동 등록을 시작하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS, ordered 27 migrations including `20260808030000_notification_device_registration.sql` and synthetic seed |
| focused device registration pgTAP | PASS, 58/58 |
| full database regression | PASS, 32 files / 1,811 pgTAP tests |
| database lint | PASS, warning level with fail-on-error; schema error 0 |
| pure endpoint Edge/runtime contract | PASS, 13/13 |
| repository JavaScript contract suite | PASS, 76/76 |
| workflow/supply-chain contract | PASS, 5 jobs, 17 pinned action uses, `contents:read`; actionlint PASS |
| focused Flutter endpoint/composition tests | PASS, 25/25 |
| full Flutter regression | PASS, 497 tests + local-connectivity opt-in 1 skip |
| full Flutter coverage | PASS, 11,411/14,487 lines, 78.77% |
| exact formatter/analyzer | PASS, 309 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| public config/secret/codegen | PASS, public config allowlist; high-confidence secret 0; generated drift 0/8 files |
| dependency/license/vulnerability | PASS, 150 Pub + 15 npm license audit; offline OSV scan PASS |
| OpenAPI and matrix structure | PASS, OpenAPI YAML parses with 17 paths/27 schemas; requirements 116×18, tests 61×11, risks 30×15, release 23×10, platform 20×12 |
| whitespace | PASS, final `git diff --check` output 0 |

Focused DB fixtures cover exact schema/check/index/FK, force-RLS/grants/search path, direct access denial, metadata-only status, initial registration, refresh, rotation, exact replay, idempotency reuse, expected-version conflict, cross-account token reassignment, wrong/correct proof and revoke replay, stale/current fingerprint invalidation, member-removal revoke, recipient/outsider/removed-member isolation and immutable content-free audit.

Edge fixtures cover exact body/header/method/query/content-type/size/CORS boundaries, GoTrue authentication, service RPC parameter allowlist, stable SQLSTATE mapping, generic proof revoke, randomized AES-GCM decryptability with version-bound AAD, canonical SHA-256 material, key validation and token/secret non-reflection.

Flutter fixtures cover installation persistence, auth/notification namespace isolation, raw-token-free secure records, pending-before-network, success promotion, exact response-loss replay, response-loss와 concurrent token rotation 경합, bounded conflict rotation, active/uncertain-pending logout purge, remote-failure proof preservation, repository failure mapping, strict RPC/function DTO envelopes and production dependency composition.

## Files and Migration

- Migration: `supabase/migrations/20260808030000_notification_device_registration.sql`
- DB tests: `supabase/tests/database/notification_device_registration.test.sql`
- Edge core/runtime: `supabase/functions/_shared/notification_endpoint_contract.mjs`, `notification_endpoint_runtime.mjs`
- Edge entry/config: `supabase/functions/notification-endpoint/index.ts`, `deno.json`, `supabase/config.toml`
- Edge tests: `scripts/ci/notification-endpoint-contract.test.mjs`
- Flutter domain/application: notification endpoint models/failure/repository, lifecycle, material generator/store ports and unavailable fallback under `apps/kinflow_app/lib/features/notifications/`
- Flutter data/infrastructure: provider repository, secure material generator/installation store and `apps/kinflow_app/lib/infrastructure/supabase/supabase_notification_endpoint_data_source.dart`
- Flutter composition/tests: `app/bootstrap.dart`, auth/notification providers, endpoint storage/lifecycle/repository/Supabase adapter/auth dependency tests
- Contracts/governance: notification endpoint/OpenAPI/database/RLS/env contracts, Phase 05 and consolidated specs, requirement/test/platform/risk/release matrices and `WP05_03_WORKPLAN.md`

## Security, Privacy, and Data

- raw provider token은 Flutter persistent state에 저장하지 않고 Edge memory 밖으로 평문 전달하지 않는다. DB ciphertext는 AES-GCM nonce/tag envelope이고 fingerprint와 proof hash는 one-way matching에만 사용한다.
- `anon`/`authenticated`는 endpoint token table이나 private audit을 직접 읽거나 쓸 수 없다. `service_role`도 raw table direct privilege가 없고 allowlisted mediated RPC만 실행한다.
- POST identity는 request body가 아니라 GoTrue가 검증한 UID에서 오며 DB가 active household member를 다시 선택한다. client는 household의 다른 user/member endpoint를 지정하거나 읽을 수 없다.
- DELETE proof는 sign-out 뒤 revoke를 가능하게 하지만 installation UUID만으로는 사용할 수 없다. 응답은 endpoint 존재 여부를 숨긴다.
- audit에는 endpoint ID, transition/reason/version/time만 있고 auth UID, household/member ID, token material, email/name/content/payload/raw error가 없다.
- server encryption key, service-role key와 provider credential은 Flutter/web public config와 repository tracked secret에 추가하지 않았다.
- 자동 검증은 synthetic UUID와 synthetic printable token, local Supabase와 fake transport만 사용했다. production project, 고객 계정, 고객 데이터나 실제 push credential은 사용하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google/Apple 계정, 실제 household, remote Supabase migration/Edge invocation과 hosted secret injection은 **NOT RUN**이다.
- Firebase project, APNs entitlement/certificate, FCM/APNs SDK와 실제 token acquisition/rotation은 **NOT IMPLEMENTED / NOT RUN**이다.
- OS permission pre-prompt/system prompt/settings recovery, iOS/Android foreground/background/terminated delivery와 local presentation은 **NOT IMPLEMENTED / NOT RUN**이다.
- provider send/receipt, ambiguous provider response reconciliation, provider-invalid token의 실제 cleanup과 delivery dedupe는 **NOT IMPLEMENTED / NOT RUN**이다.
- notification tap의 로그인/household/membership/resource 재검증과 target-specific deep link는 **NOT IMPLEMENTED / NOT RUN**이다.
- iOS Keychain/Android Keystore의 uninstall/reinstall, backup/restore, shared-device/account-switch forensic behavior는 local mock contract만 통과했고 실제 기기 검증은 마지막 Gate다.

## Remaining Risks and Completion Boundary

1. WP05-04 sender는 DB의 `token_key_version`별 복호화 key ring을 가져야 한다. 현재 registration runtime은 새 token을 current key로 seal할 뿐 old-version decrypt/rotation 운영 절차와 secret-manager 배포는 아직 없다.
2. Flutter lifecycle은 실제 provider token source를 호출하지 않는다. SDK refresh callback, permission transition과 앱 lifecycle을 연결할 때 중복 callback과 stale account race를 다시 검증해야 한다.
3. proof가 secure storage에서 소실되고 provider invalidation이나 member removal도 발생하지 않으면 stale endpoint가 남을 수 있다. 운영용 bounded revoke-all/retention 정책은 아직 없다.
4. one-active-fingerprint 재할당은 로컬 DB 동시성으로 검증했지만 provider가 token을 재사용하는 실제 조건, multi-region Edge retry와 remote PostgREST timeout은 재현하지 않았다.
5. endpoint audit와 revoked ciphertext의 retention, account deletion, legal hold, encryption-key retirement와 forensic 접근 정책은 Phase 07/08 결정이 필요하다.
6. public OpenAPI/Edge contract는 구현과 정렬했지만 remote gateway CORS, GoTrue timeout, secret injection과 hosted logs의 non-leakage는 배포 환경에서 별도 확인해야 한다.
7. Phase 05 전체와 FR-NOTIF/T-PUSH 전체는 provider delivery, permission/presentation/tap, reliability/offline과 remote/device Gate가 남아 `PARTIAL`이다. 완료로 표시하지 않는다.

WP05-03 자체는 synthetic token을 사용한 local automated vertical slice로 완료했다. 상위 기능 목표는 계속 active다.

## Rollback

- 실제 provider source가 아직 연결되지 않았으므로 Flutter production endpoint repository override를 unavailable fallback으로 되돌리거나 token-source 호출을 비활성화하면 새 registration을 격리할 수 있다.
- Edge `notification-endpoint` invocation과 service RPC execute를 중지하면 새 register/revoke/invalidate를 차단할 수 있다. 기존 inbox와 notification Outbox는 독립적으로 유지된다.
- production 적용 전에는 migration, Edge function/config, Flutter lifecycle/storage/composition, tests/contracts를 함께 revert하고 이전 26-migration/1,753-test baseline으로 clean reset한다.
- production 적용 후에는 applied migration이나 immutable audit을 수정·삭제하지 않는다. forward migration으로 registration/invalidation execute를 revoke하고 active endpoint를 allowlisted `rollback_disabled` reason으로 mediated revoke한다.
- encrypted token/audit은 승인된 retention까지 보존하고 key material은 해당 ciphertext가 제거되거나 모두 새 version으로 refresh되기 전에 폐기하지 않는다.

## Next Entry Condition

- 다음 기능 우선순위는 Phase 05 WP05-04 mobile push다.
- provider dependency Gate에서 고정 Firebase/APNs 관련 SDK 버전, platform support, license/privacy, native permission과 rollback을 먼저 기록하고 token source를 현재 `NotificationEndpointLifecycle` 뒤에 연결한다.
- sender는 versioned decrypt key ring, minimal routing-only payload, delivery idempotency/receipt, ambiguous response reconciliation과 current-fingerprint invalidation을 먼저 고정해야 한다.
- permission education/denied/settings 상태와 foreground local presentation, background/terminated bootstrap, tap 후 auth/household/membership/resource refetch를 provider와 분리된 port로 테스트 가능하게 만든다.
- synthetic/fake provider와 local automated lifecycle을 먼저 완료하고, 실제 provider project·계정·iOS/Android 기기 검증은 사용자 지시에 따라 대다수 기능 개발 후 마지막 Gate에 유지한다.
