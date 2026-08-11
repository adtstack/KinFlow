# Phase 04 WP04-01 Calendar Time Primitives Evidence

- Work Package: WP04-01 — typed local/instant values, date-only all-day range, IANA timezone adapter, deterministic DST resolver
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0, Supabase CLI 2.109.1, PostgreSQL 17, Docker 29.6.2
- 결과: **LOCAL AUTOMATED PASS / EVENT CRUD·UI·REMOTE·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-01 | PASS FOR LOCAL AUTOMATED SLICE | local date/time, UTC instant, IANA ID, all-day exclusive range, zoned intent와 client/server resolver가 exact contract로 구현됐다. |
| FR-CAL-001 (FOUNDATION) | PARTIAL | timed local intent를 pinned IANA timezone으로 canonical UTC instant에 resolve하는 타입과 private server authority를 제공한다. event table과 CRUD는 WP04-02다. |
| FR-CAL-002 (FOUNDATION) | PARTIAL | all-day를 timezone/instant가 없는 `[startDate, endDateExclusive)` exact payload로 표현하고 leap/year boundary 및 overlap/contains를 검증했다. persistence/UI는 WP04-02다. |
| FR-CAL-004 (TIME FOUNDATION) | PARTIAL | DST gap reject, overlap earlier/later와 offset 변화 뒤 local wall time 보존을 client/PostgreSQL에서 검증했다. recurrence rule/materialization은 WP04-04다. |
| FR-TODAY-001 (FOUNDATION) | PARTIAL | event local intent, canonical instant와 date-only 값을 분리해 household/device projection이 source intent를 바꾸지 않는 경계를 만들었다. event source composition은 WP04-05다. |
| D-019 | PASS FOR TIME MODEL | local recurrence/event intent와 resolved occurrence instant를 별도 값으로 유지한다. |
| D-046 | PASS FOR THIS SLICE | calendar UI package를 추가하지 않았고 time dependency는 UI contract에 노출되지 않는다. |
| D-047 | PASS FOR THIS SLICE | domain/service interface는 Flutter, Riverpod, Supabase와 `timezone` package를 import하지 않으며 package import는 data adapter에만 있다. |
| NFR-REL-01 (COMPATIBILITY) | NO REGRESSION / NOT ADVANCED | read-only resolver는 고정 tzdata에서 같은 입력을 deterministic하게 반환하고 기존 retry-safe 기능은 전체 회귀를 통과했다. event mutation/job idempotency는 이번 slice에서 추가하지 않았다. |
| NFR-COMP-01 | PASS FOR ADDITIVE LOCAL SLICE | exact dependency, domain/data 타입과 private helper만 추가했다. 기존 public RPC/schema를 변경하지 않고 18개 migration fresh reset과 전체 회귀를 통과했다. |

## Implemented Contract

- `CalendarLocalDate`는 `YYYY-MM-DD`와 Gregorian 유효 날짜만, `CalendarLocalTime`은 `HH:mm` minute precision만 허용한다. `UtcInstant`는 literal `Z` UTC instant만 허용한다.
- `IanaTimeZoneId`는 `UTC` 또는 canonical area/location shape를 허용하고 실제 database membership은 resolver가 판정한다. `PST` 같은 abbreviation과 unknown zone은 fail closed다.
- `CalendarAllDayRange`는 start inclusive/end exclusive date-only exact JSON이다. timezone, UTC instant와 device projection을 포함하지 않는다.
- `CalendarZonedDateTimeIntent` exact keys는 `localDate`, `localTime`, `timezone`, `gapPolicy`, `overlapPolicy`다. gap은 `reject`, fold default는 `earlier`이고 `later`를 명시할 수 있다.
- `TimezoneCalendarTimeResolver`는 embedded `timezone` database의 모든 unique offset candidate를 reverse-project하고 입력 local fields가 완전히 일치하는 instant만 선택한다. constructor normalization을 resolution으로 인정하지 않는다.
- `app_private.resolve_calendar_zoned_datetime`도 입력 local timestamp와 정확히 일치하는 candidate를 찾는다. invalid input/zone/policy는 internal SQLSTATE `KFT01`, candidate가 없는 gap은 `KFT02`다.
- PostgreSQL resolver는 저장 authority이고 client result는 preview/validation이다. WP04-02 public RPC가 server result를 저장·반환하고 internal SQLSTATE를 stable public error로 매핑해야 한다.
- `time-primitives.yaml.md`가 wire format, authority, all-day/DST policy와 timezone database release gate를 고정한다.

## Timezone Dependency Gate

- client dependency는 exact `timezone: 0.11.1`, license는 BSD-2-Clause다. package type는 adapter 밖으로 노출하지 않는다.
- client bundled timezone database는 2025c다. local Supabase PostgreSQL container의 `/usr/share/zoneinfo/UTC` owner는 `tzdata-2026b-r0`였고, decision date의 IANA current release는 2026c다.
- 세 database version은 서로 다르지만 서울, UTC, Los Angeles, Berlin, Lord Howe fixture의 selected instant/offset/policy가 client와 server에서 일치했다.
- version 차이가 존재하므로 production Calendar는 계속 OFF다. remote deploy 전 deployed PostgreSQL version 확인, supported scheduling window parity와 current IANA 영향 검토가 필요하다.
- runtime adapter는 embedded data만 초기화하며 device timezone 탐지, native permission, OS calendar/contact 접근 또는 외부 요청을 수행하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| exact dependency replay | PASS, `flutter pub get --enforce-lockfile --offline`; direct `timezone` 0.11.1 |
| focused Flutter time tests | PASS, 15/15 |
| focused PostgreSQL time pgTAP | PASS, 28/28 |
| clean `npx supabase db reset` | PASS, ordered forward migration 18개와 synthetic seed 적용 |
| DB schema lint | PASS, `app_private`, `extensions`, `public` error 0 |
| full pgTAP/RLS regression | PASS, 20 files, 1,073 tests; predecessor 1,045 + 신규 28 |
| full Flutter regression | PASS, 351 tests + local-connectivity opt-in 1 skip; predecessor 336 + 신규 15 |
| exact formatter/analyzer | PASS, quality scope 230 files changed 0; analyzer issue 0 |
| repository CI self-test/workflow/actionlint | PASS, 47/47; 5 jobs, pinned action 17개, workflow lint pass |
| config/secret/codegen | PASS, public config allowlist, high-confidence secret 0, generated drift 0/8 files |
| dependency license | PASS, Pub 150 and npm 15; `timezone` 0.11.1 BSD-2-Clause |
| vulnerability scan | PASS, checksum-pinned OSV Scanner 2.3.8; actual lockfiles scanned offline after database download |
| coverage | PASS, 6,630 / 8,406 lines = 78.87% |
| whitespace | PASS, `git diff --check` output 0 |

Client fixture는 strict parse/exact-key rejection, leap day/year boundary, all-day half-open semantics, unknown zone, Seoul/UTC, LA spring/fall wall-time, LA/Berlin gap, LA fold earlier/later와 Lord Howe 30-minute gap/fold를 포함한다.

PostgreSQL fixture는 exact function signature/result fields, stable invoker/empty search path, API role denial, 같은 zone/instant/offset/policy parity, invalid abbreviation/unknown zone/policy/second/null input과 internal typed errors를 포함한다.

## Data, Security, Privacy, and Platform

- 검증은 fresh local Supabase와 고정된 공개 timezone/date fixture만 사용했다. production migration, 실제 계정, household, 사용자 일정 제목·설명 또는 token은 사용하지 않았다.
- 새 database function은 `app_private`에 있고 public/anon/authenticated/service-role execute를 모두 revoke했다. authenticated는 기존 private schema usage가 있어도 이 function execute가 거부되고 service role은 schema 진입도 거부된다.
- function은 invoker-rights, `STABLE`, empty `search_path`다. public event RPC 또는 broad service-role grant는 추가하지 않았다.
- resolver input/output에는 사람·가구 content가 없고 raw timezone input/error를 관측성 payload로 기록하지 않는다. future telemetry는 allowlisted code와 database version만 허용한다.
- 새 native plugin, permission, client cache, analytics event, background task 또는 OS integration은 없다. Android/iOS/Linux/macOS/Web/Windows에서 pure Dart adapter가 제공되지만 이번 slice는 Android build/device smoke를 수행하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정, Android 실기기, 두 기기 동시 사용 검증은 **NOT RUN**이다.
- production/remote Supabase migration, deployed PostgreSQL tzdata, remote RPC와 forward rollback rehearsal은 **NOT RUN**이다.
- Android date/time picker, device timezone travel, household timezone 변경 warning, locale week start, OS/display/push 표시 검증은 **NOT IMPLEMENTED / NOT RUN**이다.
- event schema/RLS/create/edit/delete, timed/all-day persistence, household participant validation과 Calendar/Today UI는 **NOT IMPLEMENTED**다.
- daily/weekly/monthly recurrence, occurrence materialization, single exception, series update/cancel과 repair procedure는 **NOT IMPLEMENTED**다.

## Remaining Risks and Completion Boundary

1. client 2025c, local server 2026b와 current IANA 2026c drift가 있다. covered fixture는 일치하지만 future rule change가 있는 zone/date는 remote release gate 전 별도 비교가 필요하다.
2. PostgreSQL initial helper는 create/edit correctness를 위해 최대 약 32시간의 minute candidates를 검사한다. bulk recurrence materializer 전에 query profile과 optimized resolver를 검토해야 한다.
3. client preview와 remote server가 다를 때 server result를 다시 표시하고 confirmation을 요구하는 UI/error contract가 아직 없다.
4. all-day range와 timed intent는 domain contract일 뿐 database event row에 아직 저장되지 않는다. WP04-02가 DB constraints/RLS/RPC에서 같은 불변식을 다시 강제해야 한다.
5. public error mapping, event `start < end`, participant household integrity, edit/delete concurrency와 feature kill switch가 아직 없다.
6. local automated time foundation만 통과했으므로 FR-CAL, T-TIME-01, REL-014, Phase 04 또는 전체 제품 목표를 완료로 표시하지 않는다.

WP04-01 자체는 local automated time-foundation slice로 완료했다. user-visible Calendar와 release gate는 이후 WP 및 마지막 real-account/device 검증까지 `PARTIAL`을 유지한다.

## Rollback

- production 적용 전에는 dependency/lockfile, calendar domain/data files, migration/test, ADR/contract/evidence/matrix 변경을 함께 revert하고 이전 17-migration/1,045-test baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정하거나 삭제하지 않는다. 아직 public caller가 없으므로 corrective forward migration에서 function을 replace 또는 rename하고 future RPC를 disabled 상태로 유지한다.
- dependency rollback은 data adapter만 교체한다. domain/wire local date/time/timezone/policy와 PostgreSQL authority 의미는 유지한다.
- 이번 slice는 public table/row를 만들지 않으므로 사용자 data backfill 또는 destructive cleanup이 없다.

## Next Entry Condition

- 다음 기능 우선순위는 WP04-02 One-time event다: timed/all-day create/edit/delete, household participant integrity, validation/RLS와 최소 client vertical slice를 구현한다.
- WP04-02 RPC는 이 private server resolver만 persistence authority로 사용하고 all-day를 UTC 자정으로 변환하지 않아야 한다.
- 실계정·두 기기·remote Supabase와 device timezone travel gate는 사용자 지시에 따라 기능 개발이 충분히 끝난 마지막 단계까지 유지한다.
