# Phase 04 WP04-04A Recurring Calendar Creation Evidence

- Work Package: WP04-04A — strict recurring event creation, immutable source intent, bounded occurrence materialization, mixed Calendar reads
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03/WP04 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / EXCEPTION·SERIES CHANGE·ROLLING REPAIR·REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-04A | PASS FOR LOCAL AUTOMATED SLICE | UI→controller→repository→strict Supabase adapter→authenticated RPC→immutable revision/materializer→mixed v2 read 경계에서 daily/weekly/monthly recurring create가 동작한다. |
| FR-CAL-004 | IN PROGRESS | strict daily/weekly/monthly rule, count/until/never validator, first 366-local-date materialization, DST wall-time/gap/fold, monthly day-31 skip와 all-day span이 local automation을 통과했다. rolling repair와 device gate가 남았다. |
| FR-CAL-005 | PARTIAL FOUNDATION | occurrence는 immutable recurrence local date와 unique household occurrence key를 가지며 replay가 duplicate를 만들지 않는다. 이번 회차 수정/취소는 WP04-04B다. |
| FR-CAL-007 | IN PROGRESS | v2 agenda/day/month가 one-time과 recurring occurrence를 동일 overlap/order/cursor/count 계약으로 혼합한다. remote query plan/device propagation은 남았다. |
| NFR-SEC-01 | PASS FOR NEW BOUNDARY | recurring create와 mixed reads는 authenticated active household member만 실행하고 participant는 same-household active member로 다시 검증한다. |
| NFR-PRIV-01 | PASS FOR NEW STORAGE | recurring command replay와 audit storage는 title/description/display name/participant list를 복제하지 않는다. month v2는 날짜와 count만 반환한다. |
| NFR-REL-01 | PASS FOR CREATE/REPLAY SLICE | 동일 command UUID는 같은 결과를 반환하고 다른 payload 재사용을 거부하며 materializer replay는 unique slot conflict에서 0개를 추가한다. |
| NFR-COMP-01 | PASS FOR ADDITIVE LOCAL SLICE | v2 reads와 recurring create를 추가하고 legacy one-time CRUD/list/v1 page/month signatures와 behavior를 유지한 채 clean reset/full regression을 통과했다. |

## Recurrence and Database Contract

- `20260807130000_recurring_calendar_events.sql`은 recurrence end/rule을 exact-key JSON으로 검증한다. frequency는 `daily`, `weekly`, `monthly`; interval은 1–30; end는 `never`, count 1–1000, inclusive local `until`만 허용한다.
- weekly weekday는 locale-independent `MO`…`SU`의 unique non-empty 배열이며 anchor weekday를 포함해야 한다. monthly `monthDay`는 anchor day와 같아야 한다. unknown, duplicate, localized, fractional, invalid local date를 fail closed한다.
- recurring revision은 normalized title/description, timed IANA timezone 또는 all-day mode, recurrence rule과 participant set을 immutable snapshot으로 보존한다. active series projection과 revision participant history는 분리된다.
- occurrence는 `recurrence_local_start_date`와 `series_id:local-date` key를 가진다. identity update trigger와 unique household occurrence key가 replay 또는 repair 중 slot duplication을 막는다.
- initial create는 anchor부터 최대 365일 뒤까지, 즉 최대 366 local dates만 materialize한다. count/until이 먼저 끝나면 horizon을 줄인다. rolling extension/repair worker는 WP04-04C 범위다.
- timed occurrence마다 source local date/time, pinned IANA timezone과 explicit earlier/later policy를 PostgreSQL resolver에 다시 전달한다. fixed UTC interval addition을 사용하지 않는다.
- Los Angeles 40주 일요일 08:00 fixture는 spring/fall 뒤에도 08:00을 유지하고 두 UTC offset을 기록한다. spring 02:30 future gap은 전체 command를 `KFE06`으로 원자적으로 거부한다.
- fall 01:30 fold의 earlier/later recurring series는 각각 `08:30Z/-25200/overlap_earlier`와 `09:30Z/-28800/overlap_later`를 보존하면서 local 01:30을 유지한다.
- monthly day 31 count=4 fixture는 Jan/Mar/May/Jul 31을 만들며 날짜가 없는 달을 clamp하지 않는다. count는 실제 matching local date만 소비한다.
- all-day recurring occurrence는 source span을 date-only half-open range로 복제하며 timezone, instant와 DST metadata를 저장하지 않는다.
- `create_recurring_calendar_event`는 actor를 JWT에서 도출하고 UUID idempotency, active membership, same-household active participant, stable public error catalog와 content-free audit를 사용한다.
- `get_calendar_event_page_v2`는 recurrence rule, slot local date, revision number와 exception marker를 추가하고 v2 query-bound cursor를 사용한다. `get_calendar_month_summary_v2`는 두 occurrence source를 함께 센다.
- 기존 v1 page/month는 one-time-only 동작을 유지한다. 이전 Flutter client가 v1을 사용해도 recurring metadata로 인해 exact payload decoder가 깨지지 않는다.

## Flutter Vertical Slice

- platform-free domain에 strict recurrence frequency/weekday/end/rule, recurring draft/request/result와 materialization snapshot invariants를 추가했다.
- 기존 occurrence projection은 optional recurrence rule, immutable slot date, revision number와 exception marker를 수용하되 `isRecurring`으로 one-time과 구분한다.
- Supabase adapter는 recurring create의 exact result envelope와 v2 page recurrence fields를 fail closed로 해석하고 `KFE07`을 provider-neutral invalid input으로 매핑한다.
- repository는 recurrence JSON을 typed domain으로 다시 검증하고 request rule과 response rule의 exact equality, household/UUID/date/count/version invariants를 확인한다.
- controller는 client time preview에서 gap/unsupported timezone을 먼저 거부하고 recurring create retry에 같은 command UUID를 재사용한다. 성공 후 현재 agenda/day/month first page와 month summary를 authoritative하게 다시 읽는다.
- create editor는 Once/Daily/Weekly/Monthly를 제공한다. 현재 UI가 생성하는 규칙은 선택한 시작 날짜에 anchored된 interval 1, never-end 규칙이며 API/domain은 count/until과 wider interval 계약도 검증한다.
- recurring card는 localized repeat label을 표시한다. WP04-04A에서는 recurring row를 one-time update/delete RPC로 잘못 보내지 않도록 edit/delete action을 숨기며 scope mutation은 04B/04C에서 연다.
- 새 문자열은 en/ko/en-XA ARB에만 있고 wire rule에는 locale 문자열을 사용하지 않는다. 기존 200% pseudo editor scroll과 locale view tests를 유지한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx --no-install supabase db reset --local --yes` | PASS, ordered forward migration 21개와 synthetic seed 적용 |
| focused recurring Calendar pgTAP | PASS, 81/81 |
| related Calendar/time pgTAP regression | PASS, 4 files, 297/297 |
| full pgTAP/RLS regression | PASS, 23 files, 1,342 tests; predecessor 1,261 + 신규 81 |
| strict DB lint | PASS, `public`, `app_private` schema error 0 |
| focused recurrence Flutter tests | PASS, 44/44 |
| full Flutter regression | PASS, 407 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, 256 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| exact dependency replay | PASS, `flutter pub get --enforce-lockfile --offline` |
| localization/codegen | PASS, en/ko/en-XA exact coverage·pseudo expansion; generated drift 0/8 files |
| public config/secret scan | PASS, public config allowlist valid; high-confidence secret 0 |
| whitespace | PASS, `git diff --check` output 0 |

Focused DB fixture는 function/table/column/trigger/index/signature/search-path/grant, force RLS, unauthenticated/anonymous/outsider/cross-household participant denial, malformed rule/anchor/timezone/gap, weekly DST offsets, explicit recurring fold, monthly day-31/count, multi-day all-day span, command/materializer replay, immutable revision/slot, content-free private rows, mixed v1/v2 day/month, ordering/cursor/empty envelope를 포함한다.

Focused Flutter fixture는 strict rule/end round-trip와 reject cases, anchored rule/draft/snapshot invariants, exact provider page/create payload, repository request/response mapping, controller authoritative refresh/same-key retry/gap rejection, weekly create UI/label/action boundary, pseudo 200% editor와 Korean calendar view regression을 포함한다.

## Data, Security, Privacy, and Platform

- 검증은 fresh local Supabase와 deterministic synthetic UUID/name/event content만 사용했다. production migration, 실제 계정, 실제 household, 고객 일정 또는 provider token은 사용하지 않았다.
- public recurring functions는 security-definer, empty search path, authenticated-only execute다. private validator/materializer/snapshot/command state는 API role execute/select grant가 없다.
- revision participant table은 force RLS이며 authorized household read-only다. command/audit state에는 event content와 participant identity list가 없다.
- recurrence JSON은 event content, locale, device timezone, resolved instant와 offset을 포함하지 않는다. canonical instant는 server resolver 결과만 저장한다.
- Flutter domain/application은 Flutter, Riverpod와 Supabase SDK를 import하지 않는다. provider SDK는 infrastructure adapter에만 있다.
- 새 native plugin, OS Calendar permission, analytics event, persistent event cache, background worker 또는 external network dependency를 추가하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정, 실제 household, Android/iOS 실기기와 성인 2계정·두 기기 recurring create/view propagation 검증은 **NOT RUN**이다.
- production/remote Supabase migration, deployed PostgreSQL tzdata, production-size recurring cardinality/query plan/latency와 network loss/reconnect는 **NOT RUN**이다.
- device timezone travel, household timezone 변경, 실제 OS locale/date picker, VoiceOver/TalkBack와 push/display는 **NOT RUN**이다.
- single-occurrence edit/cancel exception은 **NOT IMPLEMENTED / NOT RUN**이며 WP04-04B 범위다.
- future/whole-series edit/cancel, rolling horizon repair worker와 exception-aware regeneration은 **NOT IMPLEMENTED / NOT RUN**이며 WP04-04C 범위다.
- Today Chore+Calendar composition과 Realtime multi-client conflict는 **NOT IMPLEMENTED / NOT RUN**이며 WP04-05/WP04-06 범위다.

## Remaining Risks and Completion Boundary

1. first-year materialization은 local deterministic fixture에서 검증됐지만 one-year horizon 밖을 연장/repair하는 scheduled worker, lease/crash replay와 alert는 없다.
2. future gap을 포함한 recurring command는 전체를 거부한다. 사용자에게 gap이 발생하는 회차를 설명하거나 exception으로 해결하는 UX는 후속 WP가 필요하다.
3. UI는 anchored interval-1/never 생성만 제공한다. count/until, 복수 weekday와 wider interval은 strict domain/API 계약에 있으나 편집 UX는 아직 없다.
4. mixed v2 cursor는 deterministic local test를 통과했지만 remote concurrent insert/delete와 Realtime refetch semantics는 WP04-06에 남아 있다.
5. recurring row의 edit/delete를 안전하게 숨겼으므로 accidental one-time mutation은 막지만 사용자가 series를 변경/취소할 수는 없다.
6. exception/series change/repair/Today composition과 real-account/device evidence가 없으므로 FR-CAL 전체, T-CAL-01, REL-014, Phase 04 또는 제품 목표를 완료로 표시하지 않는다.

WP04-04A 자체는 local automated recurring creation slice로 완료했다. Calendar product/release gate와 현재 장기 기능 목표는 이후 WP와 마지막 real-account/device 검증까지 `IN_PROGRESS/PARTIAL`을 유지한다.

## Rollback

- production 적용 전에는 WP04-04A migration, v2 adapter, recurrence domain/UI/l10n/tests/contracts/evidence를 함께 revert하고 WP04-03의 20-migration/1,261-pgTAP 및 392-Flutter baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정하거나 삭제하지 않는다. corrective forward migration에서 recurring create와 v2 execute를 revoke하고 client를 v1 one-time path로 되돌린다.
- existing one-time series/occurrence, canonical time intent와 participants를 rollback 때문에 삭제하지 않는다. 이미 생성된 recurring data는 별도 quarantine/forward repair policy 없이는 파괴적으로 제거하지 않는다.

## Next Entry Condition

- 다음 기능 우선순위는 WP04-04B single-occurrence edit/cancel이다. immutable recurrence slot은 유지하고 exception revision/override와 versioned idempotent commands를 추가한다.
- 04B read projection은 moved/cancelled occurrence를 mixed v2 page/month에 정확히 반영하고 siblings와 source series/revision을 변경하지 않아야 한다.
- 실계정·두 기기·remote Supabase와 device timezone travel gate는 사용자 지시에 따라 기능 개발이 충분히 끝난 마지막 단계까지 유지한다.
