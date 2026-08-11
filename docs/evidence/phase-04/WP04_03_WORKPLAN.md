# WP04-03 Work Plan — Calendar Agenda, Day, and Month Views

- 상태: LOCAL AUTOMATED COMPLETE / RECURRING·TODAY COMPOSITION·REMOTE·REAL-DEVICE DEFERRED
- 범위: WP04-02의 one-time event occurrence를 household-local agenda/day/month 화면에 범위 교차 규칙으로 표시하고 bounded keyset pagination, locale week-start, compact/tablet adaptive layout과 accessible date navigation을 제공한다.
- 다음 범위: recurring series/exception은 WP04-04, Chore+Calendar Today composition은 WP04-05, multi-client conflict/Reconnecting Realtime은 WP04-06이다.

## 요구사항과 수용 기준

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP04-03 | agenda/day/month read projection이 local automated UI→repository→RPC→RLS 경계에서 동작한다. |
| FR-CAL-007 | agenda는 household-local 오늘부터 기본 90일, explicit range는 최대 366일을 조회한다. day는 정확히 하루를 조회하고 month는 매일의 timed/all-day count와 선택한 날짜의 event list를 제공한다. |
| FR-CAL-007 | agenda/day event list는 opaque query-bound keyset cursor와 1–100 page limit을 사용하고 initial/loading/empty/error/refresh/load-more failure를 구분한다. |
| FR-CAL-007 | month grid는 `MaterialLocalizations.firstDayOfWeekIndex`와 locale date/time formatter를 사용하며 recurrence/source intent에는 locale을 저장하지 않는다. |
| NFR-A11Y-01 | view selector, previous/next/today navigation과 month date cell은 label, selected state와 event count를 semantics로 노출하고 200% text에서 핵심 action을 잃지 않는다. |
| NFR-PERF-01 | 서버 range를 366일, page를 100개로 제한하고 occurrence overlap index와 content-free month count projection을 사용한다. production-size query plan은 remote release gate로 남긴다. |
| NFR-SEC-01 | view RPC는 authenticated active household member만 실행하며 empty search path security-definer, anonymous denial과 same-household RLS 의미를 유지한다. |
| NFR-PRIV-01 | opaque cursor는 household/range/order key만 담고 title, description, participant name을 포함하지 않는다. month summary는 날짜와 count만 반환한다. |
| NFR-COMP-01 | 기존 one-time CRUD RPC signature와 source rows를 변경하지 않는 additive migration/client extension이다. |

## Read Projection Contract

1. `get_calendar_event_page`는 `agenda` 또는 `day`, optional resolved date range, limit과 opaque cursor를 받는다. initial agenda의 null range는 server household-local today부터 90일로 고정한다.
2. all-day occurrence는 date-only `[local_start_date, all_day_end_date_exclusive)`가 query range와 겹칠 때 포함한다. timezone/UTC midnight으로 변환하지 않는다.
3. timed occurrence는 canonical `[starts_at, ends_at)`가 household timezone으로 만든 query day-boundary instant와 겹칠 때 포함한다. event의 pinned timezone/source local intent는 변경하지 않는다.
4. projection order는 first visible household-local date, all-day-before-timed kind, first visible minute와 occurrence ID의 total order다. range 시작 전부터 진행 중인 event는 range 첫날 00:00 projection으로 정렬한다.
5. cursor v1은 household, view, resolved range, sort date/kind/minute와 occurrence ID를 hex-encoded exact JSON으로 묶는다. 다른 household/view/range 재사용, extra/missing key와 malformed value를 거부한다.
6. page는 limit+1로 `has_more`를 판정하며 empty result도 timezone, household-local today, generated-at, resolved query와 pagination metadata 한 행을 반환한다.
7. `get_calendar_month_summary`는 유효한 month first day에 대해 각 날짜를 정확히 한 행씩 반환하고 all-day/timed/total count를 제공한다. content, participant와 cursor는 반환하지 않는다.
8. month day count는 all-day date overlap과 timed household-day instant overlap을 각각 계산한다. 하나의 multi-day occurrence는 겹치는 각 날짜에 한 번씩 count된다.

## Flutter Vertical Slice

1. domain에 view mode, range request, opaque cursor, projected event page, month request/day summary와 append invariants를 추가한다.
2. provider repository와 Supabase adapter는 exact metadata/item/month key set, query echo, ordering, unique occurrence와 cursor/`hasMore` 관계를 fail closed로 검증한다.
3. controller는 view selection, first-page/refresh/load-more coalescing, content-preserving failures와 month summary+selected-day load를 관리한다.
4. create/update/delete 성공 뒤 현재 view를 authoritative하게 다시 조회해 range 이동, month count와 pagination을 조정한다. offline optimistic Calendar mutation은 추가하지 않는다.
5. agenda는 날짜별 section list와 load-more/retry, day는 하루 overlap list, month는 locale-aligned grid와 selected-day list를 제공한다.
6. compact는 단일 scroll surface를 사용하고 medium/expanded month는 grid와 selected-day list를 split view로 배치한다. 권한과 데이터 의미는 viewport에 따라 달라지지 않는다.
7. 사용자 문자열은 en/ko/en-XA ARB에 추가하고 Material locale date/time formatting을 사용한다. 직접 조합한 user-facing English string을 만들지 않는다.

## 자동 검증

- schema/function signature/index/search-path/grant와 legacy CRUD signature 보존
- unauthenticated/anon/outsider/removed member와 invalid range/month/cursor denial
- default household-local 90-day agenda envelope와 exact empty metadata
- timed/all-day/multi-day half-open range intersection
- day boundary의 ongoing timed event와 all-day-before-timed stable order
- limit+1, two-page no-gap/no-duplicate keyset과 query-bound cursor rejection
- month leap/non-leap day cardinality와 per-day timed/all-day/total count
- domain request/page/month invariants와 continuation merge rejection
- provider exact payload/error mapping과 controller load/refresh/load-more/view navigation
- compact/expanded agenda/day/month, locale first day, semantics와 en-XA 200% widgets
- clean reset, full pgTAP/RLS, full Flutter, analyzer, formatter, codegen/config/secret/license regression

## 배포 중단 조건과 Rollback

- all-day가 timezone 변환으로 날짜를 바꾸거나 timed overlap이 canonical instant 대신 client/device time으로 판정되면 WP04-04로 진입하지 않는다.
- cursor가 household/view/range에 묶이지 않거나 pagination이 duplicate/gap을 만들면 배포하지 않는다.
- month count가 multi-day event를 빠뜨리거나 content/participant를 노출하면 배포하지 않는다.
- production 적용 전에는 WP04-03 migration/view client/tests/contracts/evidence를 함께 revert하고 이전 19-migration/1,193-test baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정하지 않는다. corrective forward migration에서 새 read RPC execute를 revoke하고 client view selector를 agenda legacy fallback으로 disable한다.
- event/source row를 삭제하거나 UTC/local intent를 backfill하지 않는다. 이 slice는 read projection만 추가한다.

## 완료 경계

이 slice가 green이어도 recurring series/exception, conflict hints, Today Chore+Calendar composition, remote production-size query plan, 실제 계정·두 기기·device timezone travel과 assistive-technology 검증이 남으므로 FR-CAL/Phase 04/전체 목표를 완료로 표시하지 않는다.

## 완료 결과

- DB: focused 68/68, full 22 files·1,261 tests, lint issue 0, clean reset 20 migrations
- Flutter: focused 56/56, full 392 tests+1 opt-in skip, analyzer issue 0, formatter 254 files drift 0
- 세부 증빙: `docs/evidence/phase-04/WP04_03_EVIDENCE.md`
