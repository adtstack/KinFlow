# WP04-02 Work Plan — One-time Calendar Event Vertical Slice

- 상태: LOCAL COMPLETE / RECURRING·ADVANCED VIEWS·REMOTE·REAL-DEVICE DEFERRED
- 범위: active adult household member가 timed/all-day one-time event를 생성·목록 조회·수정·삭제하고 같은 가구의 active adult participants를 지정하는 DB/RLS/RPC/Flutter vertical slice를 제공한다.
- 다음 범위: day/month/agenda pagination과 locale week-start는 WP04-03, recurring series/exception은 WP04-04, Today composition은 WP04-05다.

## 요구사항과 수용 기준

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP04-02 | one-time timed/all-day event CRUD와 participant selection이 local automated UI→repository→RPC→RLS 경계에서 동작한다. |
| FR-CAL-001 | timed event는 strict local date/time + pinned IANA timezone + positive duration으로 입력되고 server resolver가 `starts_at < ends_at` canonical instant를 저장한다. create/read/update/delete를 지원한다. |
| FR-CAL-002 | all-day event는 `[local_start_date, all_day_end_date_exclusive)`만 저장하고 timezone/UTC instant/DST metadata를 저장하지 않는다. |
| FR-CAL-003 | participant는 최소 1명이며 요청 household의 active adult member만 가능하다. composite FK와 RPC validation이 cross-household/removed member를 거부한다. Managed Child는 D-013에 따라 범위 밖이다. |
| D-019 | one-time도 series definition, immutable revision과 materialized occurrence를 분리하며 occurrence key는 stable하다. |
| D-017 | event series mutation은 online-only이며 offline optimistic mutation을 만들지 않는다. |
| D-047 | domain/application은 Flutter/Riverpod/Supabase에 의존하지 않는다. |
| D-048 | create/update/delete는 idempotency key를 사용하고 update/delete는 expected series version도 검증한다. |
| NFR-SEC-01 | public tables는 force RLS + read-only grant이며 mutation은 authenticated security-definer RPC만 허용한다. caller/household/participant 권한은 server가 다시 판정한다. |
| NFR-PRIV-01 | private command/audit row에는 title/description/display name을 복제하지 않고 IDs, action, version, correlation만 기록한다. |
| NFR-COMP-01 | additive schema/RPC/client route이며 기존 Chore/Auth public contract를 변경하지 않는다. |

## Database Model

1. `event_series`는 household, normalized title/description, nullable timed timezone, `is_all_day`, active revision, creator, version와 soft-delete를 가진다.
2. `event_series_revisions`는 immutable local start date/time, duration, all-day exclusive end, gap/overlap policy와 nullable recurrence rule을 가진다. 이번 slice의 recurrence rule은 항상 null이다.
3. `event_occurrences`는 stable `series_id:once` key, active revision, local date, canonical timed instants 또는 all-day exclusive end, nullable timezone와 exact DST resolution metadata를 가진다.
4. `event_participants`는 `(household_id, series_id, member_id)` composite key/FK다. create/update 시 최소 1명의 active adult를 exact set으로 교체한다.
5. all-day series/occurrence는 timezone, local time, duration, starts/ends와 DST metadata가 모두 null이어야 한다. timed event는 그 반대이며 positive duration과 `ends_at > starts_at`을 강제한다.
6. `app_private.calendar_command_requests`는 per-user UUID idempotency key, command name/hash와 target IDs만 보존한다. request content를 복제하지 않는다.
7. `app_private.calendar_audit_events`는 create/update/delete actor·aggregate·occurrence·correlation·version만 기록하고 immutable하다.

## RPC Contract

1. `create_one_time_event`는 normalized participant set과 request hash를 advisory lock 아래 처리한다. replay는 추가 row/audit 없이 current target snapshot을 반환하되 이후 command로 삭제된 target은 다시 노출하지 않는다.
2. `update_one_time_event`는 expected series version을 검증한 뒤 새 immutable revision을 만들고 같은 occurrence identity를 새 revision/time/participant set으로 갱신한다. 삭제 후 도착한 과거 update replay도 target을 다시 노출하지 않는다.
3. `delete_one_time_event`는 expected series version을 검증하고 series soft delete + occurrence cancel을 수행한다. participant/history row는 forensic/history를 위해 보존한다.
4. `list_one_time_events`는 membership을 server에서 확인하고 household timezone/local date envelope과 non-deleted one-time event를 deterministic start/title/id 순으로 최대 100개 반환한다. advanced pagination/view intersection은 WP04-03다.
5. internal `KFT01/KFT02`는 public `KFE02` invalid input / `KFE06` nonexistent local time으로 매핑한다. 공개 오류는 auth, invalid input, forbidden/not-found, idempotency conflict, stale version, nonexistent local time만 노출한다.
6. public RPC는 empty search path security-definer, authenticated execute only다. anon은 execute 불가하고 authenticated는 public tables select만 가능하다.

## Flutter Vertical Slice

1. domain에 identifiers, participants, one-time event/list/draft/request/result/failure와 repository/id-generator interfaces를 추가한다.
2. data layer는 exact provider payload를 validate/map하고 unknown/extra/malformed relation을 `invalidPayload`로 거부한다. Supabase SDK import는 infrastructure adapter에만 둔다.
3. application controller는 initial/load/ready/load-failed와 create/update/delete pending/failure state를 직렬화한다. duplicate submit은 합치고 성공 시 local list를 authoritative response로 갱신한다.
4. `/calendar` screen은 simple deterministic list, empty/loading/error, create/edit form와 delete confirmation을 제공한다. WP04-03 day/month grid를 선행 구현하지 않는다.
5. form은 household timezone을 timed default로 사용하고 all-day/timed 전환, date/time, positive duration, exclusive end, overlap earlier/later와 1명 이상 participants를 지원한다.
6. Today app bar에서 Calendar로 진입할 수 있다. 모든 사용자 문자열은 en/ko/en-XA ARB를 사용하고 touch target/semantics/200% text automation을 추가한다.

## 자동 검증

- schema columns/checks/composite FKs/index/immutability/RLS/grants
- unauthenticated/anon/cross-household/removed participant/direct mutation denial
- timed Seoul create round-trip과 `starts_at < ends_at`
- LA gap public error와 fold earlier/later retained
- all-day exact date-only persistence 및 timezone/instant null
- create/update/delete idempotency conflict/replay와 stale version
- immutable revision 증가와 stable occurrence identity
- participant exact replacement and same-household integrity
- deleted event list suppression and forensic participant/audit retention
- domain invariants, controller serialization/retry/local replacement
- provider mapper/Supabase exact payload/error mapping
- loading/empty/create/edit/delete/error/accessibility/localization widgets
- clean reset, full pgTAP/RLS, Flutter, analyzer, architecture, config, secret, codegen, dependency regression

## 배포 중단 조건과 Rollback

- all-day row에 timezone/instant가 저장되거나 timed canonical instant가 server resolver 결과와 다르면 WP04-03으로 진입하지 않는다.
- cross-household/removed participant가 저장되거나 direct table mutation이 가능하면 배포하지 않는다.
- idempotency replay가 duplicate series/revision/audit을 만들거나 stale version을 덮어쓰면 배포하지 않는다.
- production 적용 전에는 migration/calendar CRUD files/tests/contracts/evidence를 함께 revert하고 이전 18-migration/1,073-test baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정하지 않는다. Calendar route/entry를 disable하고 corrective forward migration으로 RPC execute를 revoke한 뒤 schema/function을 보정한다.
- soft-deleted user data 또는 audit/command row를 임의 삭제하지 않는다. retention/deletion policy가 승인된 privileged job만 정리한다.

## 완료 경계

이 slice가 green이어도 advanced Calendar views/pagination, recurrence/exception, Today event composition, notification, remote tzdata, 실제 계정·두 기기·device travel 검증이 남으므로 FR-CAL/Phase 04/전체 목표를 완료로 표시하지 않는다.
