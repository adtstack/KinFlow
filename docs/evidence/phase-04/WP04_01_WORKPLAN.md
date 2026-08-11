# WP04-01 Work Plan — Calendar Time Primitives

- 상태: COMPLETE (LOCAL AUTOMATED SLICE) / EVENT CRUD·UI·REMOTE·REAL-DEVICE DEFERRED
- 범위: Instant, LocalDate, LocalTime, canonical IANA timezone, date-only all-day range와 deterministic DST gap/overlap resolution을 domain/server 계약으로 고정한다.
- 다음 범위: event series/revision/occurrence/participant schema와 timed/all-day create/read UI는 WP04-02다.

## 요구사항과 결정

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP04-01 | locale/device timezone과 무관한 time primitives와 exact serialization 및 server-authoritative DST resolver를 제공한다. |
| FR-CAL-001 (FOUNDATION) | timed local intent를 canonical UTC instant + pinned IANA timezone으로 결정하며 `start < end` 검증에 사용할 타입을 제공한다. CRUD는 WP04-02다. |
| FR-CAL-002 (FOUNDATION) | all-day는 UTC 자정으로 변환하지 않는 `[startDate, endDateExclusive)` date range로 표현한다. |
| FR-CAL-004 (FOUNDATION) | DST gap은 저장 전 거부하고 overlap은 explicit earlier/later policy로 한 instant를 선택해 local wall time을 보존한다. 반복 규칙/materialization은 WP04-04다. |
| FR-TODAY-001 (FOUNDATION) | event timezone intent와 household/device timezone projection을 섞지 않도록 UTC instant/local date 타입을 분리한다. Today composition은 WP04-05다. |
| D-019 | local recurrence intent와 canonical occurrence instant는 분리한다. |
| D-046 | calendar UI package를 추가하지 않고 recurrence/time domain은 UI package에 의존하지 않는다. |
| D-047 | domain/application은 Flutter/Riverpod 및 provider SDK와 독립적이다. timezone package는 data adapter에만 둔다. |
| NFR-REL-01 (COMPATIBILITY) | 이 read-only slice는 mutation/job idempotency를 추가하지 않는다. 고정 tzdata에서 같은 입력을 deterministic하게 resolve하고 기존 retry-safe 기능을 회귀 검증한다. |
| NFR-COMP-01 | additive types, private helper와 contract만 추가하고 기존 chore RPC/client behavior를 변경하지 않는다. |

## Dependency Gate

1. `timezone` 0.11.1을 exact pin한다. labs.dart.dev publisher, Android/iOS/Linux/macOS/Web/Windows 지원, BSD-2-Clause, pure Dart embedded IANA database이며 native permission이 없다.
2. package의 bundled TZDB는 2025c이고 2026-08-07 IANA current는 2026c다. client adapter는 preview/validation일 뿐 authority가 아니며 package DB version을 코드로 노출한다.
3. PostgreSQL resolver가 저장용 canonical instant의 authority다. remote deploy 전 server tzdata와 current IANA release를 비교하고 client/server fixture parity를 다시 실행한다.
4. `time_machine2`는 richer typed API를 제공하지만 pre-1.0 API debt, rootBundle initialization, 추가 culture/assets/dependencies와 현재 작은 adoption surface 때문에 이번 slice에서는 선택하지 않는다.
5. Dart core `DateTime`만으로 IANA zone과 ambiguous/nonexistent local time을 표현하지 않는다.
6. package는 adapter 뒤에 격리한다. rollback 시 domain contract/server resolver를 유지한 채 adapter와 dependency를 교체할 수 있다.

## Product Time Policy

1. `CalendarLocalDate`는 strict `YYYY-MM-DD`, `CalendarLocalTime`은 minute-precision `HH:mm`, `UtcInstant`는 UTC `Z` instant만 허용한다.
2. `IanaTimeZoneId`는 `UTC` 또는 canonical area/location shape만 허용하고 실제 지원 여부는 resolver database가 판정한다. abbreviation/device timezone name을 identity로 사용하지 않는다.
3. `CalendarAllDayRange`는 start inclusive/end exclusive이고 end가 start보다 뒤여야 한다. timezone 또는 UTC instant를 포함하지 않는다.
4. `CalendarZonedDateTimeIntent` exact keys는 `localDate`, `localTime`, `timezone`, `gapPolicy`, `overlapPolicy`다.
5. gap policy는 Store MVP에서 `reject`로 고정한다. local time을 다음 유효 시각으로 조용히 이동하지 않는다.
6. overlap policy는 `earlier`가 기본이고 `later`를 명시할 수 있다. 선택한 policy와 resolution kind를 저장/응답 계약에 유지한다.
7. event timezone은 생성 시 pinned된다. device travel이나 household timezone 변경은 intent를 조용히 바꾸지 않는다.
8. client clock은 authority가 아니다. WP04-02 RPC가 server resolver 결과를 저장하고 반환한다.

## 구현

1. calendar domain에 local date/time, UTC instant, IANA ID, all-day range, zoned intent와 typed resolution result/interface를 추가한다.
2. calendar data adapter에 embedded `timezone` DB resolver를 추가한다. unknown zone, gap, normal, overlap earlier/later를 exception leak 없이 typed result로 반환한다.
3. `app_private.resolve_calendar_zoned_datetime(date,time,timezone,overlap_policy)`를 private invoker function으로 추가한다. current PostgreSQL tzdata에서 exact local wall time과 일치하는 candidate instant를 찾고 gap은 `KFT02`, invalid input/zone/policy는 `KFT01`로 거부한다.
4. private function은 public/anon/authenticated/service-role execute를 모두 revoke한다. WP04-02 create RPC의 security-definer owner만 내부 호출한다.
5. `time-primitives.yaml.md`에 wire contract와 authority/drift 규칙을 기록한다.
6. ADR-0003에 dependency, DST policy, privacy/platform/rollback/revisit gate를 기록한다.

## 자동 검증

- strict date/time/instant/IANA parsing과 exact JSON key/version independence
- all-day exclusive end, leap day, year boundary, contains/overlap/day count와 timezone travel 불변성
- Seoul/UTC basic round trip
- Los Angeles spring gap reject와 fall overlap earlier/later one-hour separation
- Berlin spring gap과 Lord Howe 30-minute gap/overlap
- weekly local wall time across spring/fall offset change
- unknown/alias timezone fail closed
- client adapter/server resolver expected instant parity for covered fixtures
- private function signature/search path/grants and exact typed errors
- full pgTAP/RLS/Flutter/architecture/config/secret/codegen/dependency-license regression

## 배포 중단 조건과 Rollback

- gap을 normal instant로 silently normalize하거나 overlap policy와 다른 instant를 선택하면 WP04-02로 진입하지 않는다.
- all-day date가 timezone projection으로 바뀌거나 serialization이 locale-dependent이면 배포하지 않는다.
- client/server가 같은 fixture에서 다른 instant를 선택하면 remote calendar 기능을 켜지 않는다.
- production 적용 전에는 migration/dependency/domain/adapter/contracts/tests/evidence를 함께 revert한다.
- production 적용 후에는 applied migration을 수정하지 않는다. future create RPC entry를 disable하고 corrective forward migration으로 resolver를 교체한다.
- timezone dependency rollback은 adapter 구현만 교체하며 stored local intent/timezone/policy/UTC contract를 변경하지 않는다.

## 완료 경계

이 slice가 green이어도 event schema/RLS/CRUD, participant, Calendar/Today UI, recurrence/materialization, remote tzdata와 실제 device timezone 검증이 남으므로 FR-CAL과 Phase 04 전체를 완료로 표시하지 않는다.
