# Phase 05 WP05-02 Notification Preferences and Durable Inbox Evidence

- Work Package: WP05-02 — category preference, IANA quiet hours, latest-state inbox materialization, durable read/unread/badge, Flutter notification center
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 WP02-06/WP03/WP04/Phase 05 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2, Node 24.15.0, npm 11.12.1, Supabase CLI 2.109.1, PostgreSQL 17 local stack
- 결과: **WP05-02 LOCAL AUTOMATED PASS / ENDPOINT·PROVIDER·HOSTED·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-02 / FR-NOTIF-003 | PASS FOR LOCAL CHORE INBOX SLICE / OVERALL PARTIAL | WP05-01 resolution을 최신 occurrence/series/recipient와 현재 preference로 다시 평가해 content-free durable inbox로 materialize한다. Calendar event reminder와 provider send는 남았다. |
| WP05-02 / FR-NOTIF-004 | PASS FOR LOCAL QUIET-HOUR SLICE / OVERALL PARTIAL | 사용자·household·category별 IANA timezone과 quiet interval을 저장하고 자정 교차, DST gap-forward, fold-later를 결정적으로 계산한다. 자동 travel timezone 갱신과 실제 provider timing은 남았다. |
| WP05-02 / FR-NOTIF-006 | PASS FOR LOCAL INBOX DEDUPE SLICE / OVERALL PARTIAL | source event당 immutable evaluation 한 건과 item 최대 한 건, `FOR UPDATE SKIP LOCKED`, response-loss replay, superseded 취소, read/preference replay를 검증했다. provider receipt는 남았다. |
| WP05-02 / FR-NOTIF-007 | PASS FOR CURRENT CHORE CATEGORIES / OVERALL PARTIAL | `chore_due`, `chore_assignment`별 in-app/native-push 설정과 quiet hours UI/API를 구현했다. Calendar event와 approval category producer/settings는 남았다. |
| WP05-02 / CAP-005 | PASS FOR LOCAL AUTOMATED SLICE | recipient 전용 durable inbox, stable keyset page, 개별/전체 읽음, server-authoritative unread badge와 Today 진입점을 Flutter에 연결했다. |
| NFR-SEC-01 / NFR-SEC-02 | PASS FOR NEW SURFACE | 모든 authenticated API가 `auth.uid()`와 active membership을 다시 확인한다. client direct write와 service-role private-table access를 막고 mobile bundle에 worker/service secret을 추가하지 않았다. |
| NFR-PRIV-01 | PASS FOR NEW PAYLOAD | inbox/API payload exact keys는 `householdId`, `occurrenceId`뿐이다. title, description, display name, email, token, provider body, raw error를 저장·반환하지 않는다. |
| NFR-REL-01 / NFR-COMP-01 | PASS FOR NEW LOCAL SLICE | concurrent materializer, duplicate/replay, late state, disabled preference, read replay가 멱등이며 기존 producer/worker/Chore/Calendar API를 additive migration으로 유지한다. |

## Database and API Contract

- `public.notification_preferences`는 `(auth_user_id, household_id, category)` key와 네 channel flag, paired minute-precision quiet interval, valid IANA timezone, optimistic version을 가진다. 저장 행이 없으면 household timezone과 version 0의 두 category default projection을 반환한다.
- preference update는 exact expected version을 요구한다. 다른 값에 stale version을 사용하면 `KNP06`으로 닫고, 동일 값을 재전송하는 response-loss replay는 기존 version을 반환한다.
- `public.notification_inbox_items`는 source event/aggregate version, server-resolved recipient, category/subject routing IDs, schedule, read/cancel state와 exact two-key payload만 저장한다. routing envelope는 immutable이고 read/cancel transition만 단방향이다.
- `app_private.notification_inbox_evaluations`는 source event별 `created|disabled|stale|suppressed`, preference version, later-delivery timing과 stable reason만 immutable하게 기록한다.
- authenticated API는 preference get/update, inbox keyset list, unread count, bounded item read와 snapshot read-all이다. 모든 호출은 authenticated UID와 active household를 server-side에서 bind하며 read mutation 뒤 authoritative unread count를 반환한다.
- service-role-only `materialize_chore_notification_inbox(batch, as_of)`는 1–100개 resolution을 `FOR UPDATE SKIP LOCKED`로 claim한다. 응답은 claimed/created/disabled/stale/suppressed/cancelled count와 timestamp뿐이다.
- newer aggregate version이나 terminal suppression은 동일 household/category/subject의 이전 active item을 `superseded|state_inactive`로 취소한다. cancelled row는 page와 badge에서 제외하지만 audit evidence로 유지한다.

## Quiet Hours and Materialization Semantics

- quiet interval은 같은 날 구간과 자정을 넘는 구간을 모두 지원하며 start와 end가 같거나 한쪽만 있는 값, 초 단위 값, 알 수 없는 timezone은 거부한다.
- reference instant가 quiet interval 밖이면 그대로 반환한다. interval 안이면 local quiet end를 UTC instant로 해석한다.
- DST gap에 quiet end가 놓이면 첫 valid local minute로 전진하고 `gap_forward`, fold에 놓이면 두 instant 중 나중 instant를 선택해 `overlap_later`로 기록한다.
- quiet hours는 `delivery_not_before` snapshot만 계산한다. durable in-app item은 즉시 생성되므로 push provider 장애나 quiet interval 때문에 inbox가 사라지거나 늦게 나타나지 않는다.
- materializer는 WP05-01의 과거 candidate를 그대로 신뢰하지 않고 latest resolver를 다시 실행한다. completed/skipped/inactive/recipient-changed event는 stale/suppressed로 확정하며 category `in_app=false`는 disabled로 확정한다.
- Edge worker는 claim/process loop가 끝날 때 같은 `asOf`로 materializer를 호출한다. source claim이 0건이어도 미처 materialize되지 않은 durable resolution을 복구할 수 있으며 response는 aggregate-only다.

## Flutter Contract

- notification domain은 category, preference/version, content-free inbox item, cursor/page/snapshot과 read receipt를 framework-independent 값으로 검증한다.
- Supabase adapter는 RPC별 exact key/type/UUID/timestamp/payload와 repeated cursor metadata를 strict parse한다. extra content-shaped key, household mismatch, malformed page/read response는 provider detail 없이 stable failure로 닫는다.
- controller는 initial/refresh/load-more, preference update, item/all read를 serialize하고 server unread count를 authority로 사용한다. transient failure는 안전한 기존 content를 유지하지만 unauthenticated/forbidden은 snapshot을 제거한다.
- Today의 bell은 server badge를 표시하고 notification center route를 연다. item 선택은 먼저 unread를 mark한 뒤 Today로 이동해 기존 authorized query를 다시 실행한다. raw notification payload를 화면 content로 렌더링하지 않는다.
- 설정 화면은 `chore_due|chore_assignment`별 in-app/native-push opt-in과 quiet interval/timezone을 저장한다. native push는 preference만 미리 저장하며 실제 delivery는 device registration 이후라는 localized copy를 표시한다.
- en/ko/en-XA ARB와 generated localization을 사용하고 presentation → application → domain 의존 방향, 30% pseudo expansion과 widget behavior를 자동 검증한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS, ordered 26 migrations including `20260808020000_notification_preferences_and_inbox.sql` and synthetic seed |
| focused preference/inbox pgTAP | PASS, 85/85 |
| focused materializer concurrency pgTAP | PASS, 10/10 |
| full database regression | PASS, 31 files / 1,753 pgTAP tests |
| database lint | PASS, warning level with fail-on-error; schema error 0 |
| pure notification worker contract | PASS, 16/16 including exact aggregate-only materializer response |
| repository JavaScript contract suite | PASS, 63/63 |
| workflow/supply-chain contract | PASS, 5 jobs, 17 pinned action uses, `contents:read` |
| focused Flutter notification tests | PASS, 18/18 domain/repository/controller/widget/strict Supabase adapter/composition tests |
| architecture/localization correction tests | PASS, 8/8 |
| full Flutter regression | PASS, 477 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, 293 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| public config/secret/codegen | PASS, public config allowlist; high-confidence secret 0; generated drift 0/8 files |
| matrix structure | PASS, requirements 116×18, tests 61×11, risks 30×15, release 23×10, platform 20×12 |
| whitespace | PASS, final `git diff --check` output 0 |

Focused DB fixtures cover exact tables/functions/output/grants/search path, force-RLS and direct-write denial, default projection, version conflict/replay, cross-midnight and normal/gap/fold timing, item/evaluation privacy, recipient/outsider/removed-member isolation, stable pagination, individual/all read replay, badge counts, disabled category, latest-state suppression, superseding cancellation, replay, and externally locked concurrent materializers.

Flutter fixtures cover invalid identifiers/timezones/quiet intervals, provider result mapping, controller authorization purge versus transient retention, load-more/read/preference transitions, badge/item/settings UI, Today navigation, exact Supabase DTO keys/types/cursor/payload, dependency direction, complete en/ko/en-XA coverage and pseudo expansion.

## Files and Migration

- Migration: `supabase/migrations/20260808020000_notification_preferences_and_inbox.sql`
- DB tests: `supabase/tests/database/notification_preferences_and_inbox.test.sql`, `notification_inbox_materializer_concurrency.test.sql`
- Worker integration: `supabase/functions/_shared/notification_worker_contract.mjs`, `scripts/ci/notification-worker-contract.test.mjs`
- Flutter domain/application/data/presentation: `apps/kinflow_app/lib/features/notifications/`
- Supabase adapter/composition: `apps/kinflow_app/lib/infrastructure/supabase/supabase_notification_data_source.dart`, `app/bootstrap.dart`, `app/providers/auth_dependencies.dart`, router and Today notification entry
- Localization: en/ko/en-XA ARB plus generated localizations
- Flutter tests: notification domain/repository/controller/widget, strict Supabase adapter, dependency composition and shared fake dependencies
- Contracts/governance: notification inbox/worker/database/RLS contracts, Phase 05 document, implementation/master snapshots, requirements/test/platform/risk/release matrices and `WP05_02_WORKPLAN.md`

## Security, Privacy, and Data

- client는 preference/inbox table을 SELECT만 할 수 있고 모든 write는 bounded security-definer RPC로 수행한다. `anon`은 table/API를 사용할 수 없으며 removed member와 outsider는 동일한 not-found/forbidden 경계로 닫힌다.
- materializer만 inbox/evaluation을 쓸 수 있다. `service_role`에도 private evaluation/source tables나 quiet helper direct privilege를 주지 않았고 aggregate-only mediated API만 허용했다.
- inbox payload와 Flutter DTO에는 household/occurrence routing ID만 있다. 앱은 title/description/member name을 notification 저장소에서 얻지 않고 Today의 기존 authorization boundary로 다시 조회한다.
- preference에는 category/channel boolean, quiet local time, timezone과 version만 저장한다. push token, installation ID, locale, provider receipt는 이번 table에 섞지 않았다.
- mobile/web public config와 dependency에는 service-role key, scheduler secret, Firebase/APNs credential 또는 새 runtime SDK를 추가하지 않았다. secret scan과 codegen drift가 green이다.
- 자동 검증은 synthetic UUID/content와 local Supabase만 사용했다. production project, 고객 계정, 실제 token/provider 또는 고객 데이터를 사용하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 계정, 실제 household, remote Supabase migration/Edge invocation, 실제 사용자 preference/inbox round trip은 **NOT RUN**이다.
- iOS/Android 실기기의 OS notification permission, FCM/APNs token, foreground/background/terminated delivery, notification tray/local display와 tap은 **NOT IMPLEMENTED / NOT RUN**이다.
- installation identity, token rotation/revoke, logout/account switch/member-removal endpoint purge와 invalid-token cleanup은 **NOT IMPLEMENTED / NOT RUN**이며 WP05-03 범위다.
- provider send/receipt dedupe, ambiguous response reconciliation, OS lifecycle와 target-specific push deep link는 **NOT IMPLEMENTED / NOT RUN**이며 WP05-04 범위다.
- hosted scheduler, production secret manager, remote queue/inbox alert, retention cleanup, throughput/query-plan과 incident drill은 **NOT RUN**이다.
- actual travel timezone 자동 갱신과 real DST travel rehearsal은 **NOT RUN**이다. 현재 사용자는 IANA timezone을 명시적으로 변경할 수 있다.

## Remaining Risks and Completion Boundary

1. local worker contract는 materializer를 호출하지만 hosted scheduler가 없어 production queue/inbox가 자동으로 깨어나지 않는다.
2. `in_app=false`는 이후 source event를 차단하며 기존 inbox item을 소급 삭제하지 않는다. 이 non-retroactive 의미를 제품 copy/retention 정책에서 최종 승인해야 한다.
3. item 선택은 occurrence ID를 보존하지만 현재 Chore target 전용 deep-link/highlight가 없어 Today 전체를 refetch한다. target-specific route는 push tap authz와 함께 후속 범위다.
4. inbox는 화면 진입/Today refresh 시 갱신된다. provider 또는 Realtime invalidation이 없으므로 앱이 열린 상태의 즉시 갱신은 WP05-04 integration 전까지 보장하지 않는다.
5. quiet-hour timing은 DB에서 결정적이지만 실제 provider enqueue/send 직전 재평가와 travel timezone sourcing이 아직 없다.
6. immutable evaluation과 cancelled/read item의 retention, account/household deletion, legal hold와 storage/vacuum 비용은 Phase 07 정책과 production volume 검증이 필요하다.
7. Phase 05 전체와 FR-NOTIF 전체는 endpoint/token/provider/hosted/remote/device Gate가 남아 `PARTIAL`이다. 완료로 표시하지 않는다.

WP05-02 자체는 local automated vertical slice로 완료했다. 상위 기능 목표는 계속 active다.

## Rollback

- inbox만 운영 중지하려면 Edge worker에서 materializer 호출을 제거하거나 service-role execute를 forward migration으로 revoke하고 Flutter route/provider override와 Today bell을 비활성화한다. WP05-01 source Outbox/worker는 계속 사용할 수 있다.
- 전체 notification worker를 긴급 중지할 때는 기존 pause API로 새 claim/materialization을 막는다. 기존 Chore mutation과 source event 보존에는 영향을 주지 않는다.
- production 적용 전에는 migration, worker contract, Flutter feature/composition/localization/tests/contracts를 함께 revert하고 이전 25-migration baseline으로 clean reset한다.
- production 적용 후에는 applied migration이나 immutable audit를 수정·삭제하지 않는다. forward migration으로 execute/policy를 축소하고 새 materialization을 중지하며 기존 content-free item/evaluation은 승인된 retention까지 보존한다.
- migration은 additive라 기존 WP03 producer, WP05-01 resolution, Chore/Calendar RPC signature를 변경하지 않는다. Flutter fallback repository로 route를 숨겨도 기존 Today 기능은 유지된다.

## Next Entry Condition

- 다음 기능 우선순위는 Phase 05 WP05-03 device registration이다.
- WP05-03는 installation identity, user/environment/platform binding, encrypted token-at-rest/fingerprint, token rotation과 idempotent upsert, logout/account-switch/member-removal revoke, invalid-token cleanup을 먼저 고정해야 한다.
- endpoint API는 auth UID를 server-side에서 bind하고 client가 다른 user/member/household endpoint를 읽거나 변경하지 못하게 해야 한다. service/provider secret과 raw token은 log, error, inbox payload와 Flutter state에 노출하지 않는다.
- WP05-03에서도 provider send와 OS permission/presentation을 결합하지 않는다. endpoint lifecycle이 독립적으로 테스트 가능해진 뒤 WP05-04 mobile push로 진행한다.
- 실계정·remote·실기기 검증은 사용자 지시에 따라 대다수 기능 개발 후 마지막 Gate에 유지한다.
