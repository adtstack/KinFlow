# Phase 05 WP05-02 Notification Preferences and Durable Inbox Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-08)`
- 범위: WP05-01의 content-free candidate/suppression을 현재 사용자 설정과 최신 권한 상태로 다시 평가해 durable in-app inbox로 materialize하고, category별 opt-in, IANA timezone 기반 quiet hours, 읽음/안읽음과 server-authoritative badge를 Flutter에서 사용 가능하게 만든다.
- 제외: FCM/APNs endpoint와 token lifecycle(WP05-03), provider send·OS permission·foreground/background/terminated presentation·notification tap deep link(WP05-04), hosted scheduler와 실계정·실기기 검증

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP05-02 / FR-NOTIF-004 | 사용자·household·category별 quiet hours와 IANA timezone을 서버에 보존한다. 자정을 넘는 구간과 DST gap/overlap을 결정적으로 계산하고, inbox 생성 자체는 quiet hours와 분리한다. |
| WP05-02 / FR-NOTIF-007 | 현재 producer가 존재하는 `chore_due`, `chore_assignment` 각각에 대해 in-app opt-in을 조회·변경한다. 누락된 설정은 household timezone을 사용하는 명시적 기본값으로 해석한다. |
| WP05-02 / FR-NOTIF-003 | WP05-01 resolution을 latest-state와 현재 preference로 다시 평가하고 source event당 최대 한 번 inbox 결과를 확정한다. 늦거나 순서가 바뀐 event는 이전 active item을 취소하고 최신 상태만 노출한다. |
| WP05-02 / CAP-005 | recipient 전용 durable inbox, 안정적인 keyset pagination, idempotent 개별/전체 읽음 처리, server-authoritative unread badge를 앱에서 제공한다. |
| NFR-SEC-01 / NFR-SEC-02 | auth UID와 active household membership을 서버가 bind한다. client는 inbox insert/delete, recipient 변경, unread count 위조를 할 수 없고 service materializer만 mediated API로 쓰기 가능하다. |
| NFR-PRIV-01 | inbox와 API payload는 routing identifier만 저장·반환한다. title, description, member name, email, auth subject, token, provider body, raw error는 포함하지 않는다. |
| NFR-REL-01 | concurrent materializer, response-loss replay, duplicate source event, preference update replay, read replay가 멱등이며 poison/provider failure와 무관하게 inbox가 유지된다. |
| NFR-COMP-01 | WP05-01 outbox/resolution과 기존 Chore/Calendar RPC는 additive migration으로 유지한다. push delivery가 없어도 앱 inbox 기능을 독립적으로 테스트할 수 있다. |

## Data and API Impact

- `public.notification_preferences`: authenticated user + household + category의 in-app opt-in, quiet start/end, IANA timezone, optimistic version을 저장한다. 누락 행은 two-category default projection으로 반환한다.
- `public.notification_inbox_items`: source event, server-resolved recipient, household/category/subject routing identifiers, schedule, read/cancel state와 exact content-free payload를 저장한다.
- `app_private.notification_inbox_evaluations`: 모든 WP05-01 resolution의 `created|disabled|stale|suppressed` materialization 결과, preference version과 quiet-hours delivery-not-before를 source event당 한 번 기록한다.
- authenticated mediated APIs:
  - `get_notification_preferences(household_id)`
  - `update_notification_preference(household_id, category, in_app, quiet_start, quiet_end, timezone, expected_version)`
  - `list_notification_inbox_items(household_id, limit, before_created_at, before_id)`
  - `get_notification_unread_count(household_id)`
  - `mark_notification_inbox_items_read(household_id, item_ids)`
  - `mark_all_notification_inbox_read(household_id, through_created_at)`
- service-role-only API:
  - `materialize_chore_notification_inbox(batch_size, as_of)`

## Verification

- table/check/index/FK/RLS/grant/security-definer/search-path exact pgTAP
- preference defaults, cross-midnight quiet hours, normal/DST gap/DST overlap, version conflict and response-loss replay
- candidate create, category disabled, WP05-01 suppression, stale-latest-state, superseding cancellation, duplicate/concurrent materialization
- recipient isolation, removed-member denial, payload privacy, stable page cursor, individual/all read replay and badge counts
- Supabase DTO strict parsing, repository mapping/failure mapping, controller state transitions, settings/inbox widget behavior and route/navigation tests
- clean local reset, focused/full pgTAP, DB lint, full Flutter tests/analyzer/formatter, repository contract/config/secret checks

## Security and Privacy

- mobile bundle에는 service role이나 worker secret을 추가하지 않는다. materializer API는 service role만 실행하며 private tables에 direct grant를 추가하지 않는다.
- authenticated API는 `auth.uid()`와 active membership을 매 호출 재검증한다. 모든 inbox 조회와 read mutation은 recipient UID가 일치하는 행으로 제한한다.
- durable payload는 `householdId`, `occurrenceId` 두 키만 허용하고 household content를 앱 알림 저장소에 복제하지 않는다. 화면은 필요 시 기존 authorized domain query로 내용을 다시 가져온다.

## Rollback

- materializer 호출을 중단하면 WP05-01 outbox와 Chore mutation은 계속 동작한다. 앱 route/provider를 이전 구성으로 되돌려 inbox/settings 진입점을 숨길 수 있다.
- production 전에는 migration, Flutter feature, tests, contracts를 함께 revert한다.
- production 후에는 applied migration을 수정하지 않는다. forward migration으로 APIs를 revoke하고 새 materialization을 정지하며 inbox/evaluation 행은 audit evidence로 보존한다.

## Completion Boundary

- local automated DB + Flutter 기능과 회귀가 green이면 WP05-02 local slice를 완료한다.
- 실제 push endpoint/token은 WP05-03, provider delivery/permission/app lifecycle/deep-link tap은 WP05-04에 남긴다.
- hosted scheduler와 실제 계정·실기기 검증은 사용자 지시에 따라 대다수 기능 개발 뒤 마지막 gate에서 수행한다.

## Result

- clean local reset과 DB lint가 통과했다.
- focused pgTAP 85/85와 materializer concurrency 10/10, full DB 31 files/1,753 tests가 통과했다.
- worker contract 16/16, repository JavaScript 63/63, Flutter notification focused 18/18과 full 477 tests(+ local-live 1 skip)가 통과했다.
- Dart format 293 files/0 changes, analyzer issue 0, public config/secret/codegen/matrix/whitespace gate가 통과했다.
- 상세 결과와 deferred 범위는 `docs/evidence/phase-05/WP05_02_EVIDENCE.md`에 기록했다.
