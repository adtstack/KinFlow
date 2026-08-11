# Phase 04 WP04-03 Calendar Views Evidence

- Work Package: WP04-03 — household-local agenda/day/month views, range overlap, keyset pagination, adaptive Flutter UI
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03/WP04-01/WP04-02 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / RECURRING·TODAY COMPOSITION·REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-03 | PASS FOR LOCAL AUTOMATED SLICE | one-time occurrences가 UI→controller→repository→strict provider adapter→mediated RPC→RLS 경계에서 agenda/day/month로 조회된다. |
| FR-CAL-007 | IN PROGRESS | household-local 기본 90일 agenda, 정확히 하루인 day, 날짜별 count와 선택 날짜 목록인 month, bounded keyset pagination과 loading/empty/error가 local automation을 통과했다. remote/device gate가 남았다. |
| NFR-A11Y-01 | PASS FOR NEW AUTOMATED SURFACE | 보기 선택, 이전/다음/오늘, 선택 상태와 count가 있는 월 날짜 semantics를 제공하며 en-XA 200% compact와 expanded/Korean locale widget 검증을 통과했다. 실제 VoiceOver/TalkBack은 남았다. |
| NFR-I18N-01 | PASS FOR NEW AUTOMATED SURFACE | en/ko/en-XA exact ARB coverage, Material locale date/time과 `firstDayOfWeekIndex` 기반 weekday ordering을 사용한다. |
| NFR-PERF-01 | PARTIAL FOUNDATION | 서버 range 366일, page 100개를 상한으로 두고 timed/all-day overlap partial index와 content-free month count projection을 추가했다. representative data query plan/latency는 remote gate다. |
| NFR-SEC-01 | PASS FOR NEW BOUNDARY | 두 read RPC는 authenticated active household member만 실행하고 empty search path, security definer, anonymous/outsider/removed denial을 유지한다. |
| NFR-PRIV-01 | PASS FOR VIEW PAYLOAD | cursor는 query/order identifiers만 포함하고 event content와 participant identity를 포함하지 않는다. month RPC는 날짜와 세 count만 반환한다. |
| NFR-COMP-01 | PASS FOR ADDITIVE LOCAL SLICE | migration은 additive이며 WP04-02 CRUD RPC signature와 legacy list behavior를 보존한 채 clean reset과 전체 회귀를 통과했다. 실제 N-1 app/remote upgrade rehearsal은 남았다. |

## Database and Read Contract

- `20260807120000_calendar_view_queries.sql`은 timed canonical instant overlap과 all-day date overlap을 위한 partial index 두 개를 추가한다.
- `get_calendar_event_page`는 `agenda`/`day`, optional date range, 1–100 limit과 optional opaque cursor를 받는다. initial agenda의 null range는 서버가 household-local 오늘부터 90일로 해석하며 explicit range는 최대 366일이다.
- all-day는 date-only `[local_start_date, all_day_end_date_exclusive)` 교차로 조회한다. UTC midnight 또는 device timezone으로 변환하지 않는다.
- timed는 저장된 canonical `[starts_at, ends_at)`와 household timezone day-boundary instant의 교차로 조회한다. event의 pinned timezone과 source local intent는 변경하지 않는다.
- 정렬 키는 first-visible household-local date, all-day-before-timed, first-visible minute, occurrence ID다. query 시작 전부터 이어지는 occurrence는 첫날 00:00에 투영된다.
- cursor v1은 exact JSON의 version, household, view, resolved range와 정렬 키를 hex로 인코딩한다. malformed/extra/missing key와 다른 household/view/range 재사용을 거부한다. 이는 opaque transport이지 비밀 또는 암호화 토큰이 아니다.
- `limit + 1`로 `has_more`를 계산하며 empty page도 household timezone/local date, generated-at, resolved range와 pagination metadata를 한 행으로 반환한다.
- `get_calendar_month_summary`는 유효한 month first day부터 정확히 한 row/day를 반환한다. multi-day all-day와 household midnight을 넘는 timed occurrence는 겹치는 각 날짜에 한 번씩 세고 total은 all-day+timed와 일치한다.
- 두 함수는 stable security-definer, empty search path이며 authenticated execute만 허용한다. 기존 `list_one_time_events`와 create/update/delete signature 및 source row는 바꾸지 않았다.

## Flutter Vertical Slice

- platform-free domain에 `CalendarViewMode`, strict page request/range/cursor, projected event page, month request/day summary와 continuation append invariants를 추가했다.
- Supabase adapter는 page metadata/event projection과 month row의 exact key set, provider time/timestamptz normalization, query echo, page-limit type, metadata consistency와 cursor/`hasMore` 관계를 fail closed로 검증한다.
- repository는 provider record를 typed household/date/time/page/month domain으로 변환하며 순서, occurrence uniqueness, contiguous month dates와 count partition을 다시 검증한다.
- controller는 agenda/day/month 전환, 이전/다음/household-local 오늘, content-preserving refresh, exact keyset load-more와 month summary+selected-day 조회를 직렬화한다.
- create/update/delete 성공 뒤 현재 view의 first page와 month summary를 authoritative하게 다시 읽는다. Calendar offline optimistic outbox나 title-bearing cache는 추가하지 않았다.
- agenda는 household-local 날짜별 section, day는 정확히 하루의 overlap list, month는 locale-aligned grid와 선택한 날짜 목록을 제공한다.
- compact는 dropdown view selector와 단일 scroll surface를 사용한다. medium은 segmented selector, expanded month는 grid와 selected-day list를 나란히 배치한다. month cell은 최소 336dp grid를 가로 스크롤 가능하게 해 48dp 폭을 보존한다.
- month cell semantics는 locale date, event count와 selected state를 포함한다. 날짜 이동과 today action에는 tooltip/label이 있고 생성·수정·삭제 editor는 WP04-02 동작을 유지한다.
- 새 사용자 문자열은 en/ko/en-XA ARB에만 있으며 Material locale weekday/date/time formatter를 사용한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean `npx --no-install supabase db reset` | PASS, ordered forward migration 20개와 synthetic seed 적용 |
| focused Calendar view pgTAP | PASS, 68/68 |
| full pgTAP/RLS regression | PASS, 22 files, 1,261 tests; predecessor 1,193 + 신규 68 |
| strict DB lint | PASS, `app_private`, `extensions`, `public` warning/error 0 |
| focused Calendar Flutter tests | PASS, 56/56 |
| full Flutter regression | PASS, 392 tests + local-connectivity opt-in 1 skip |
| exact formatter/analyzer | PASS, quality scope 254 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| exact dependency replay | PASS, `flutter pub get --enforce-lockfile --offline`; 신규 dependency 0 |
| localization/codegen | PASS, en/ko/en-XA exact coverage·pseudo expansion; generated drift 0/8 files |
| public config/secret scan | PASS, public config allowlist valid; high-confidence secret 0 |
| whitespace | PASS, `git diff --check` output 0 |

Focused DB fixture는 function/index/signature/search-path/grant, unauthenticated/anonymous/outsider/removed member, invalid view/range/month/cursor, default 90-day envelope, empty metadata, all-day exclusive end, ongoing timed household-midnight overlap, all-day-before-timed order, two-page no-gap/no-duplicate cursor, cursor query binding/content exclusion, leap/month cardinality, per-day count partition, delete suppression과 legacy list compatibility를 포함한다.

Focused Flutter fixture는 month-end/leap date arithmetic, request/page/month invariants, all-day/timed ordering, exact continuation merge, strict provider page/month mapping, metadata-only page와 malformed limit rejection, controller view/month selection and retained summary, keyset append, existing CRUD, expanded month selection, Korean weekday order/semantics와 en-XA 200% editor access를 포함한다.

## Data, Security, Privacy, and Platform

- 검증은 fresh local Supabase와 deterministic synthetic UUID/name/event content만 사용했다. production migration, 실제 계정, 실제 household, 고객 일정 또는 provider token은 사용하지 않았다.
- month payload에는 title, description, participant/member ID 또는 cursor가 없다. page cursor에는 title/description/display name/token이 없고 strict decoder가 extra key도 거부한다.
- read RPC는 caller와 active membership을 서버에서 다시 확인한다. anonymous, outsider와 removed member는 event content뿐 아니라 month count도 읽을 수 없다.
- source event timezone/local intent, occurrence identity와 CRUD mutation semantics는 view projection 때문에 변경되지 않는다.
- Flutter domain/application은 Flutter, Riverpod와 Supabase SDK를 import하지 않는다. provider SDK는 infrastructure adapter에만 있다.
- 새 native plugin, OS Calendar permission, analytics event, persistent event cache, background worker 또는 external network dependency를 추가하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정, 실제 household, Android/iOS 실기기와 성인 2계정·두 기기 view/CRUD propagation 검증은 **NOT RUN**이다.
- production/remote Supabase migration, deployed PostgreSQL tzdata, production-size `EXPLAIN (ANALYZE, BUFFERS)`, latency와 network loss/reconnect는 **NOT RUN**이다.
- device timezone travel, household timezone 변경, 실제 OS locale/date picker, VoiceOver/TalkBack와 representative tablet journey는 **NOT RUN**이다.
- recurring event series/materialization/single-occurrence exception/future-series edit-cancel은 **NOT IMPLEMENTED / NOT RUN**이며 WP04-04 범위다.
- Today Chore+Calendar partial-failure-safe composition과 Realtime multi-client conflict는 **NOT IMPLEMENTED / NOT RUN**이며 WP04-05/WP04-06 범위다.

## Remaining Risks and Completion Boundary

1. overlap index와 bounded query 계약은 local deterministic fixture에서 검증했지만 production cardinality/statistics에서의 query plan과 p75 latency는 측정하지 않았다.
2. Material locale weekday order와 semantics tree는 widget automation을 통과했지만 실제 screen reader focus order와 tablet ergonomics를 증명하지 않는다.
3. cursor는 title-free이며 query-bound지만 remote multi-client insert/delete가 page 사이에 발생하는 snapshot semantics와 Realtime refetch는 WP04-06에 남아 있다.
4. month count와 selected-day page는 각각 authoritative RPC다. 현재 직렬 controller는 consistency metadata를 확인하지만 원격 두 요청 사이의 concurrent mutation UX는 live conflict gate가 필요하다.
5. view query는 현재 one-time revision만 포함한다. recurring materialization이 추가될 때 동일 overlap/order/cursor 계약을 재사용하고 mixed one-time/recurring regression을 추가해야 한다.
6. recurring/Today composition과 real-account/device evidence가 없으므로 FR-CAL 전체, T-CAL-01, REL-014, Phase 04 또는 제품 목표를 완료로 표시하지 않는다.

WP04-03 자체는 local automated Calendar view slice로 완료했다. Calendar product/release gate는 이후 WP와 마지막 real-account/device 검증까지 `IN_PROGRESS/PARTIAL`을 유지한다.

## Rollback

- production 적용 전에는 WP04-03 migration, view domain/data/controller/UI/l10n/tests/matrices/evidence를 함께 revert하고 이전 19-migration/1,193-test baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정하거나 삭제하지 않는다. corrective forward migration에서 두 read RPC execute를 revoke하고 client selector를 legacy agenda fallback으로 disable한다.
- event/source rows, canonical UTC/local intent와 participant를 view rollback 때문에 삭제하거나 backfill하지 않는다. cursor는 durable data가 아니므로 client가 first page를 다시 조회한다.

## Next Entry Condition

- 다음 기능 우선순위는 WP04-04 recurring Calendar event다. daily/weekly/monthly series, immutable revision, bounded occurrence materialization, one-occurrence exception과 future/whole-series edit/cancel을 추가한다.
- WP04-04는 WP04-03의 overlap/order/cursor/month contract를 one-time과 recurring occurrence에 공통 적용하고 past occurrence/source intent를 보존해야 한다.
- 실계정·두 기기·remote Supabase와 device timezone travel gate는 사용자 지시에 따라 기능 개발이 충분히 끝난 마지막 단계까지 유지한다.
