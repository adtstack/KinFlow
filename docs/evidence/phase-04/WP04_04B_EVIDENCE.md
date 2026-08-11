# Phase 04 WP04-04B Single Recurring Calendar Occurrence Evidence

- Work Package: WP04-04B — one recurring occurrence edit/cancel, immutable exception revision, moved/cancelled v2 projection
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03/WP04 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / WHOLE-SERIES·ROLLING REPAIR·REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-04B | PASS FOR LOCAL AUTOMATED SLICE | UI→controller→repository→strict Supabase adapter→authenticated RPC→normalized exception/revision→v2 page/month 경계에서 반복 일정 한 회차 수정·취소가 동작한다. |
| FR-CAL-005 | PASS FOR SINGLE-OCCURRENCE LOCAL SLICE | 수정은 target occurrence만 새 immutable revision을 사용하고 취소는 target만 제외한다. source series/active revision, recurrence slot/key와 sibling occurrence는 유지된다. |
| FR-CAL-007 | IN PROGRESS | moved occurrence는 새 overlap/date/order에 정확히 한 번 나타나고 원래 날짜에서는 사라진다. cancelled occurrence는 v2 page와 month count에서 제외된다. remote/live propagation은 남았다. |
| NFR-SEC-01 | PASS FOR NEW BOUNDARY | update/cancel RPC는 JWT actor, active household membership, target series/occurrence와 same-household active participants를 서버에서 다시 검증한다. |
| NFR-PRIV-01 | PASS FOR NEW STORAGE | exception command replay와 audit에는 event content와 participant list가 없고 generic override JSON은 `{}`로 제한된다. |
| NFR-REL-01 | PASS FOR OCCURRENCE COMMAND SLICE | expected occurrence version과 UUID idempotency가 stale overwrite와 duplicate mutation을 막는다. 같은 key+payload replay는 같은 compact result를 반환한다. |
| NFR-COMP-01 | PASS FOR ADDITIVE LOCAL SLICE | additive table/RPC와 기존 v2 signatures를 유지한 채 clean reset, one-time v1/v2, recurring create와 전체 회귀를 통과했다. |

## Database and API Contract

- `20260807140000_recurring_calendar_occurrence_exceptions.sql`은 `event_occurrence_exceptions`를 household/series/occurrence composite identity에 묶고 한 occurrence당 한 exception만 허용한다.
- generic `override_payload`는 빈 object만 허용한다. 실제 수정 내용은 새 immutable `event_series_revisions`와 `event_revision_participants` snapshot에 정규화하고 exception row는 해당 revision을 가리킨다.
- exception identity와 empty override는 update trigger로 불변이다. 반복 수정은 exception pointer/version만 전진시키므로 이전 revision history가 남는다.
- `update_recurring_calendar_occurrence(...)`는 full event draft, participant set, expected occurrence version과 UUID idempotency key를 받는다. PostgreSQL time resolver가 timed local intent를 다시 검증하고 gap은 원자적으로 거부한다.
- 수정 command는 target occurrence의 effective revision/date/time/instant만 변경한다. `recurrence_local_start_date`, occurrence key, source series/active revision과 siblings는 변경하지 않는다.
- `cancel_recurring_calendar_occurrence(...)`는 target occurrence status와 exception cancel marker만 원자적으로 전진시킨다. 이미 취소된 회차, one-time occurrence 또는 허용되지 않은 상태 전이는 stable `KFE08`로 거부한다.
- 두 command 모두 동일 authenticated user+UUID replay를 compact identifier/version/cancelled result로 재생하고 다른 payload의 key 재사용, stale version과 invalid transition을 fail closed한다.
- 기존 `get_calendar_event_page_v2(...)`와 `get_calendar_month_summary_v2(...)` signatures는 바뀌지 않는다. update 후 target은 새 effective revision과 `is_exception=true`로 새 range에 투영되고 cancel 후 page/count에서 제외된다.
- content-free `app_private.calendar_occurrence_exception_command_requests`와 Calendar audit action `calendar.occurrence_updated`/`calendar.occurrence_cancelled`만 추가했다. API roles에는 private table access가 없다.
- exception public table은 force RLS와 authenticated read-only grant를 사용하고 active household membership 및 live source series를 요구한다. direct insert/update/delete grant는 없다.

## Flutter Vertical Slice

- platform-free domain에 occurrence revision identifier, update/cancel request와 compact command snapshot invariants를 추가했다.
- repository와 Supabase data source는 update/cancel RPC의 exact-key request/result envelope를 검증하며 malformed provider payload를 domain 밖으로 유출하지 않는다.
- adapter는 `KFE08`을 provider-neutral occurrence transition failure로 매핑하고 raw provider exception/message를 사용자에게 노출하지 않는다.
- controller는 occurrence version 기반 optimistic command와 same-key retry를 사용한다. 성공하면 현재 agenda/day page와 month summary를 authoritative하게 다시 읽어 moved/cancelled projection을 동기화한다.
- pending state는 occurrence identity로 분리해 같은 recurring series의 다른 카드 action을 잘못 잠그지 않는다.
- recurring card에 localized "이번 회차 수정"과 "이번 회차 취소"를 추가했다. 수정 editor는 occurrence scope를 명시하고 취소는 event title을 포함한 확인 dialog를 거친다.
- 수정된 회차는 localized modified label을 표시한다. card/action/editor key는 occurrence identity를 포함해 동일 series의 여러 회차가 한 화면에 있어도 고유하다.
- 사용자 문자열은 en/ko/en-XA ARB와 generated localization에만 추가했고 command/status wire values에는 locale 문자열을 사용하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx --no-install supabase db reset --local --yes` | PASS, ordered forward migration 22개와 synthetic seed 적용 |
| focused occurrence-exception pgTAP | PASS, 65/65 |
| full pgTAP/RLS regression | PASS, 24 files, 1,407 tests; predecessor 1,342 + 신규 65 |
| strict DB lint | PASS, `public`, `app_private` schema error 0 |
| focused occurrence Flutter tests | PASS, 48/48 |
| full Flutter regression | PASS, 419 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, 257 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| exact dependency replay | PASS, `flutter pub get --enforce-lockfile --offline` |
| localization/codegen | PASS, en/ko/en-XA exact coverage·pseudo expansion; generated drift 0/8 files |
| public config/secret scan | PASS, public config allowlist valid; high-confidence secret 0 |
| whitespace | PASS, `git diff --check` output 0 |

Focused DB fixture는 table/column/FK/index/trigger, function signature/search path/grant, force RLS, unauthenticated/anonymous/outsider/cross-household denial, participant validation, malformed input, DST gap atomicity, stale version, invalid transition, idempotency replay/conflict, repeated edit history, source/sibling/slot immutability, content-free private rows, moved/cancelled v2 page/month projection과 legacy regression을 포함한다.

Focused Flutter fixture는 request/result invariants, exact DTO/error mapping, repository RPC mapping, controller authoritative refresh/same-key retry/stale/transition handling, recurring occurrence edit/cancel/confirmation/modified-state UI, occurrence-specific key uniqueness, Korean/pseudo-locale/200% editor regression을 포함한다.

## Files and Contract Surfaces

- Database: `supabase/migrations/20260807140000_recurring_calendar_occurrence_exceptions.sql`
- Database tests: `supabase/tests/database/recurring_calendar_occurrence_exceptions.test.sql`
- Flutter domain/application/data/UI: `apps/kinflow_app/lib/features/calendar/`
- Supabase adapter: `apps/kinflow_app/lib/infrastructure/supabase/supabase_calendar_data_source.dart`
- Flutter tests: `apps/kinflow_app/test/features/calendar/`, `apps/kinflow_app/test/infrastructure/supabase_calendar_data_source_test.dart`, `apps/kinflow_app/test/support/fakes/fake_calendar_dependencies.dart`
- Contracts/matrices: `docs/contracts/database-schema.sql.md`, `docs/contracts/rls-contract.sql.md`, `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`, `docs/matrices/TEST_MATRIX.csv.md`, `docs/matrices/TIME_RECURRENCE_TEST_MATRIX.csv.md`, `docs/matrices/RISK_REGISTER.csv.md`, `docs/matrices/RELEASE_CHECKLIST.csv.md`

## Data, Security, Privacy, and Platform

- fresh local Supabase와 deterministic synthetic UUID/name/event content만 사용했다. production migration, 실제 계정/household, 고객 일정 또는 provider token은 사용하지 않았다.
- public commands는 security-definer, empty search path, authenticated-only execute다. actor/household/participant/target identity를 client payload만 신뢰하지 않는다.
- public exception rows는 household composite FKs, immutable identity, strict empty override, force RLS와 read-only grant를 사용한다. private command/audit rows에는 title, description, display name 또는 participant identity list가 없다.
- Flutter domain/application은 Flutter, Riverpod와 Supabase SDK를 import하지 않는다. provider SDK와 SQLSTATE mapping은 infrastructure adapter에 남는다.
- 새 native plugin, OS Calendar permission, analytics event, persistent event cache, background job, domain outbox/notification emission 또는 external network dependency를 추가하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정, 실제 household, Android/iOS 실기기와 성인 2계정·두 기기 edit/cancel propagation은 **NOT RUN**이다.
- production/remote Supabase migration, production-size query plan/latency, concurrent remote clients와 network loss/reconnect는 **NOT RUN**이다.
- device timezone travel, actual OS locale/date picker, VoiceOver/TalkBack, push/display와 notification delivery는 **NOT RUN**이다.
- whole-series future edit/cancel과 exception-aware regeneration/rolling horizon repair는 **NOT IMPLEMENTED / NOT RUN**이며 WP04-04C 범위다.
- Today Chore+Calendar composition과 Realtime multi-client conflict는 **NOT IMPLEMENTED / NOT RUN**이며 WP04-05/WP04-06 범위다.
- occurrence mutation에 대응하는 domain outbox/notification intent는 이번 범위에 추가하지 않았고 후속 notification integration에서 결정한다.

## Remaining Risks and Completion Boundary

1. 한 회차 exception은 local automation에서 안전하지만 series active revision이 바뀌거나 materializer가 장기 horizon을 수리할 때 예외를 보존하는 정책/worker는 아직 없다.
2. 취소 뒤 되돌리기와 exception 자체 삭제는 현재 UI/API 범위가 아니다. 사용자는 취소 전에 confirmation을 거치지만 restore 기능은 후속 결정이 필요하다.
3. 수정된 회차는 source slot과 다른 날짜로 이동할 수 있다. whole-series change와 rolling repair가 이를 중복 생성하거나 덮어쓰지 않는 fixture가 WP04-04C에 필요하다.
4. v2 moved/cancelled projection은 deterministic local DB에서 검증됐지만 concurrent remote insert/update와 Realtime refetch semantics는 남아 있다.
5. domain outbox/notification hook이 없으므로 다른 household 기기에 mutation 알림을 전달하는 것은 아직 보장하지 않는다.
6. whole-series change, repair, Today composition, Realtime 및 real-account/device evidence가 없으므로 FR-CAL 전체, T-CAL-01, REL-014, Phase 04 또는 제품 목표를 완료로 표시하지 않는다.

WP04-04B 자체는 local automated single-occurrence edit/cancel slice로 완료했다. Calendar product/release gate와 현재 장기 기능 목표는 이후 WP와 마지막 real-account/device 검증까지 `IN_PROGRESS/PARTIAL`을 유지한다.

## Rollback

- production 적용 전에는 WP04-04B migration, occurrence command/UI/l10n/tests/contracts/evidence를 함께 revert하고 WP04-04A의 21-migration/1,342-pgTAP 및 407-Flutter baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정하거나 삭제하지 않는다. corrective forward migration에서 occurrence command EXECUTE를 revoke하고 client의 recurring occurrence actions를 숨긴다.
- 이미 생성된 exception/revision/history row는 rollback 때문에 파괴적으로 삭제하지 않는다. v2 clients는 corrected forward projection을 사용하고 legacy v1 one-time path는 유지한다.

## Next Entry Condition

- 다음 기능 우선순위는 WP04-04C whole-series edit/cancel과 exception-aware rolling repair다.
- whole-series change는 새 immutable active revision을 만들고 future occurrence projection을 versioned/idempotent하게 갱신하되 04B exception과 immutable recurrence slots를 보존해야 한다.
- repair worker는 bounded horizon, lease/crash replay, duplicate prevention, exception preservation과 observability를 local automation으로 먼저 닫는다.
- 실계정·두 기기·remote Supabase와 device timezone travel gate는 사용자 지시에 따라 기능 개발이 충분히 끝난 마지막 단계까지 유지한다.
