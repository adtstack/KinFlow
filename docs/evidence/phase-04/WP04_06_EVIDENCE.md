# Phase 04 WP04-06 Conflict, Deep-link, and Realtime Recovery Evidence

- Work Package: WP04-06 — expected-version recovery, deleted/stale occurrence deep link, Calendar/Today Realtime reconnect
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 WP02-06/WP03/WP04 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2, local Supabase CLI stack
- 결과: **LOCAL AUTOMATED PASS / OVERLAP HINT·REMOTE·REAL-ACCOUNT·TWO-DEVICE·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-06 / FR-CAL-005 / FR-CAL-006 | PASS FOR LOCAL AUTOMATED SLICE | 기존 expected occurrence/series version을 유지하고 stale/not-found mutation 결과를 locator와 authoritative refetch로 `latest reloaded` 또는 `target unavailable`로 복구한다. 자동 last-write-wins는 추가하지 않았다. |
| WP04-06 / FR-CAL-007 | PASS FOR LOCAL AUTOMATED SLICE | UUID occurrence route가 server-returned household-local date를 열고 최대 100-row pages, 500-row bound에서 target을 highlight한다. 삭제·취소·권한변경·잘못된 target은 content-free unavailable 화면으로 닫는다. |
| WP04-06 / FR-TODAY-004 | IN PROGRESS | Realtime disconnect 중 Calendar와 Today Calendar가 마지막 성공 content를 유지하고 stale/reconnect 상태를 표시한다. persistent offline cache/outbox와 실제 background/device 검증은 남았다. |
| WP04-06 / FR-TODAY-005 | PASS FOR NEW LOCAL FAILURE SLICE | Today Calendar channel 상태와 refetch 실패는 Calendar source에만 남고 Chore content와 action 상태를 숨기지 않는다. 실제 network loss/throttle은 남았다. |
| NFR-SEC-01 | PASS FOR NEW DB SURFACE | watermark는 active household member SELECT-only force-RLS이고 client write, outsider, removed member를 차단한다. locator도 active membership과 scheduled undeleted target을 다시 확인한다. |
| NFR-PRIV-01 | PASS FOR NEW PAYLOAD | Realtime record는 household id, monotonic generation, timestamp 세 필드뿐이다. locator도 content 없이 id/date/version만 반환하고 raw provider detail을 UI나 상태에 노출하지 않는다. |
| NFR-REL-01 | PASS FOR NEW LOCAL SLICE | initial-query/subscription gap, connected/reconnect/resume full refetch, duplicate/out-of-order generation, in-flight drain, idempotent replay와 target deletion을 unit/widget/pgTAP으로 검증했다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR NEW LOCAL SURFACE | unavailable/conflict/disconnected/reconnect/highlight 상태가 ARB en/ko/en-XA와 semantic action을 사용하고 compact 200% text 회귀를 통과했다. 실제 VoiceOver/TalkBack은 남았다. |
| FR-CAL-008 | **NOT STARTED BY THIS SLICE** | canonical 요구사항은 같은 구성원의 일정 overlap 힌트다. WP04-06의 expected-version conflict와 의미가 다르므로 완료로 표시하지 않았다. |

## Database and Transport Contract

- `public.calendar_sync_watermarks`는 household당 한 행이며 exact columns는 `household_id`, `generation`, `changed_at`이다. event title/description, participant, actor, command/correlation id를 저장하거나 publication하지 않는다.
- interactive command는 `app_private.calendar_audit_events` insert 뒤 watermark를 증가시킨다. idempotent replay가 audit row를 추가하지 않으면 generation도 증가하지 않는다.
- rolling horizon처럼 audit가 없는 occurrence insert/update는 statement transition table로 변경된 household마다 한 번 watermark를 증가시킨다.
- table은 `supabase_realtime` publication에 추가되고 active member에게 SELECT만 허용한다. 모든 client write와 private helper execute는 거부한다.
- `get_calendar_occurrence_locator(household_id, occurrence_id)`는 scheduled, undeleted, readable target에 한해 household timezone/local today/generated-at, target view date, identifiers와 current versions만 반환한다.
- missing/deleted/cancelled/unauthorized target은 동일한 `not found or forbidden` 경계로 합쳐 target 존재 여부나 content를 누출하지 않는다.

## Client Recovery Contract

- initial authoritative query 뒤 household-filtered channel을 연다. `subscribed`를 받은 즉시 한 번 full refetch해 query/subscription gap을 닫는다.
- generation은 strictly monotonic하게 소비한다. duplicate/older value는 무시하고 refresh 중 newer value는 하나의 후속 full refetch로 drain한다.
- disconnect는 마지막 content를 제거하지 않고 stale banner를 표시한다. reconnect와 app resume은 기존 channel을 제거하고 새 channel을 만든 뒤 cursor/delta 없이 full refetch한다.
- transport/internal 실패와 달리 unauthenticated 또는 household not-found/forbidden refetch는 이전 Calendar/Today snapshot을 즉시 폐기한다. 권한 상실을 일반 stale content로 취급하지 않는다.
- malformed or contentful-shaped Realtime payload는 적용하지 않고 disconnected 상태로 fail closed한다. raw SDK error와 payload는 사용자 UI에 전달하지 않는다.
- stale mutation target이 남아 있으면 최신 selection을 보여주고 사용자의 재결정을 요구한다. target이 사라졌으면 content-free unavailable 상태를 보여준다.
- Today Calendar source는 같은 session을 재사용하며 Chore controller/provider 생명주기와 실패 상태를 변경하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS, ordered 24 migrations including `20260808000000_calendar_conflict_realtime_and_locator.sql` |
| focused pgTAP | PASS, 38/38 |
| full database regression | PASS, 27 files / 1,565 pgTAP tests |
| database lint | PASS, warning level with fail-on-error; schema error 0 |
| focused Flutter Calendar/Today sync/deep-link/conflict | PASS, 85/85 controller/session/adapter/widget tests |
| full Flutter regression | PASS, 464 tests + local-connectivity opt-in 1 skip |
| full Flutter coverage | PASS, 10,078/12,710 lines, 79.29% |
| exact formatter/analyzer | PASS, 275 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| exact dependency replay | PASS, `flutter pub get --enforce-lockfile --offline`; lockfile SHA-256 `23be7be55bef306c8c5423873047bee3dd7c9c2e7a5d1265f7d9ae241e279ba5` |
| localization/codegen | PASS, en/ko/en-XA message expansion contract and generated drift 0/8 files |
| public config/secret scan | PASS, public config exact allowlist; high-confidence secret 0 |
| whitespace | PASS, `git diff --check` output 0 after implementation and evidence updates |

Focused fixtures cover content-free strict payload keys/UTC timestamp, provider and RPC failure mapping, connected gap closure, duplicate/out-of-order generations, in-flight drain, disconnect/reconnect/resume/dispose, transport failure retention versus authorization-loss purge, stale version with newer authoritative versions, deleted target, valid deep-link day/highlight, bounded pagination, unavailable safe copy, retained 200% pseudo content, Today source isolation and Today-card exact occurrence navigation.

## Files and Migration

- Migration and pgTAP: `supabase/migrations/20260808000000_calendar_conflict_realtime_and_locator.sql`, `supabase/tests/database/calendar_conflict_realtime_and_locator.test.sql`
- Domain/application/data ports: `apps/kinflow_app/lib/features/calendar/domain/entities/calendar_occurrence_locator.dart`, `calendar_sync_signal.dart`, `domain/repositories/calendar_sync_repository.dart`, `application/calendar_sync_session.dart`, Calendar repository/data-source locator extensions
- Supabase adapters: `apps/kinflow_app/lib/infrastructure/supabase/supabase_calendar_sync_data_source.dart`, locator mapping/RPC in `supabase_calendar_data_source.dart`
- Controller/UI/router: Calendar controller/state/providers/screen, Today Calendar controller/state/providers/widget, Today event occurrence navigation, `AppRoutes.calendarEvent`
- Composition: `apps/kinflow_app/lib/app/bootstrap.dart`, `auth_dependencies.dart`; sync repository remains nullable/disabled in test or unavailable compositions
- Localization: en/ko/en-XA ARB plus generated localizations
- Tests: Calendar sync session/controller/widget/provider, Today Calendar controller/composition widget, Supabase Calendar and sync adapter tests, shared Calendar fakes
- Contracts: `docs/contracts/calendar-sync.yaml.md`, database/RLS/domain-event contracts and Phase 04 matrices

## Security, Privacy, and Data

- 새 public row는 content-free invalidation metadata뿐이며 event content를 Realtime transport에 복제하지 않는다. content는 기존 authenticated RPC/RLS boundary를 통해 다시 읽는다.
- removed member와 outsider는 watermark와 locator를 읽을 수 없다. unauthorized target과 deleted target은 동일한 safe failure로 합쳐진다.
- reconnect/refetch가 인증 만료나 household 권한 상실을 확인하면 controller는 이전에 읽었던 Calendar snapshot도 즉시 버린다. 단순 transport 실패에서만 stale content를 유지한다.
- client는 watermark를 insert/update/delete할 수 없고 private generation helper/trigger function을 실행할 수 없다.
- raw provider exception, channel error, event payload, participant/actor id, UUID command/correlation id를 log나 error UI에 추가하지 않았다.
- runtime dependency, native permission, persistent local cache, analytics event, background task를 추가하지 않았다.
- 자동 검증은 synthetic UUID/content만 사용했고 production project, 실제 계정, token 또는 고객 데이터를 사용하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정, 실제 household, 두 계정·두 기기 concurrent edit와 실제 Supabase Realtime frame 검증은 **NOT RUN**이다.
- iOS/Android 실기기의 background/foreground channel lifecycle, airplane mode/network throttle, long disconnect, process restart와 VoiceOver/TalkBack은 **NOT RUN**이다.
- remote migration rehearsal, Realtime publication/RLS latency, production-size query plan과 p75/p95는 **NOT RUN**이다.
- `FR-CAL-008` 같은 구성원 overlap 힌트는 **NOT IMPLEMENTED / NOT RUN**이다.
- persistent offline cache/outbox는 **NOT IMPLEMENTED / NOT RUN**이다.

## Remaining Risks and Completion Boundary

1. local pgTAP은 publication membership과 RLS를 검증하지만 실제 hosted Realtime gateway의 reconnect timing, token refresh와 RLS propagation은 아직 검증하지 않았다.
2. generation은 invalidation 힌트라 delivery가 손실될 수 있다. correctness는 connect/reconnect/resume full refetch에 의존하며 background 중 즉시 반영을 보장하지 않는다.
3. interactive event mutation은 occurrence statement trigger와 audit trigger 모두를 거칠 수 있어 generation이 한 command에 한 번보다 많이 증가할 수 있다. 소비자는 monotonic cursor만 요구하고 정확한 +1을 가정하지 않는다.
4. occurrence deep link는 100-row page, 최대 500-row bound다. 하루 500개를 넘는 비정상 가구에서는 target content를 추측하지 않고 invalid payload로 닫는다.
5. stale mutation 뒤 target이 다른 날짜로 이동했더라도 현재 selection을 authoritative refetch한다. deep-link route와 highlighted target sync는 locator date를 다시 열지만 mutation UX의 자동 날짜 전환은 별도 개선 여지가 있다.
6. Phase 04 전체와 장기 기능 목표는 remote/device gate, overlap hint, 상세 Today feed ordering과 offline 정책 때문에 `IN_PROGRESS/PARTIAL`을 유지한다.

## Rollback

- client rollback은 sync repository wiring, Calendar/Today sync session, locator/deep-link/conflict UI, ARB와 관련 tests/docs를 함께 revert한다. nullable sync repository를 유지하면 기존 initial/resume/manual refetch 동작으로 안전하게 비활성화할 수 있다.
- DB rollback은 먼저 `calendar_sync_watermarks`를 `supabase_realtime` publication에서 제거하고 occurrence/audit triggers, private helper functions, locator RPC, policy와 table 순으로 제거한다.
- migration은 additive이며 existing Calendar content/series/occurrence schema와 기존 mutation/read signatures를 변경하지 않는다. 이미 생성된 watermark row는 content-free이므로 제거해도 event data 손실이 없다.

## Next Entry Condition

- 다음 기능 우선순위는 Phase 05 WP05-01 outbox/job worker의 claim lease, bounded retry, dead letter, idempotent handler와 monitoring/replay vertical slice다.
- Phase 05 진입 전 기존 Chore outbox와 향후 Calendar/Today notification producer가 intent로 연결될 때 actor/participant/content가 worker payload나 operational logs로 누출되지 않는 exact payload 계약을 먼저 적는다.
- `FR-CAL-008` overlap 힌트와 MASTER Today 다섯 구간 ordering은 별도 작은 UI/read-model slice로 추적한다.
- 실계정·remote·실기기 검증은 사용자 지시에 따라 대다수 기능 개발 후 마지막 gate에 유지한다.
