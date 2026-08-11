# ADR-0003 — Calendar time primitives와 DST resolution

- 상태: ACCEPTED
- 작성일: 2026-08-07
- 결정일: 2026-08-07
- 결정자: Product owner direction / Engineering
- 관련 요구사항: WP04-01, FR-CAL-001, FR-CAL-002, FR-CAL-004, FR-TODAY-001
- 관련 결정: D-019, D-046, D-047, D-048
- 관련 위험: RISK-005
- 대체 ADR: 없음

## Context

Calendar는 사용자가 입력한 local date/time과 IANA timezone을 보존하면서 materialized occurrence마다 canonical UTC instant를 가져야 한다. Dart `DateTime`은 UTC 또는 device local만 구분하므로 named IANA zone, nonexistent spring time과 duplicated fall time을 충분히 표현하지 못한다.

Phase 03 chore는 PostgreSQL timezone 변환을 사용했지만 gap/fold의 사용자 의미를 의도적으로 미정 상태로 남겼다. Phase 04 진입 전 client preview와 server persistence가 같은 policy를 사용하고 all-day가 UTC instant로 오염되지 않는 계약이 필요하다.

2026-08-07 기준 IANA current release는 2026c다. `timezone` 0.11.1은 labs.dart.dev가 배포하고 Android/iOS/Linux/macOS/Web/Windows를 지원하며 bundled database는 2025c다. 따라서 bundled client data를 persistence authority로 둘 수 없다.

## Decision Drivers

- IANA named zone과 DST gap/overlap을 deterministic하게 처리
- Android 우선이지만 future Web/iOS domain contract 유지
- Flutter/Riverpod/UI package와 독립적인 domain types
- native permission/device timezone 탐지/외부 network 없는 adapter
- PostgreSQL과 client fixture parity 및 tzdata drift visibility
- 작은 rollback surface와 dependency license/maintenance 검증

## Options Considered

### Option A — `timezone` 0.11.1 adapter + PostgreSQL authority

- 장점: active labs.dart.dev publisher, broad platform support, high adoption, small focused API, BSD-2-Clause, embedded IANA DB.
- 단점: package TZDB 2025c가 IANA 2026c보다 뒤이고 typed LocalDate/LocalTime/gap/fold policy를 app이 정의해야 한다.
- privacy/security: embedded `data/latest.dart`만 사용한다. device timezone 탐지, native permission, token, external request가 없다.
- migration/compatibility: exact version과 adapter DB version을 pin하고 server result를 authority로 둔다.
- 운영/비용: dependency와 tzdata release를 각 Calendar RC에서 검토한다.

### Option B — `time_machine2` 0.14.0

- 장점: Instant/LocalDate/LocalTime/ZonedDateTime와 skipped/ambiguous resolver를 포함한 richer type system, TZDB 2026a.
- 단점: pre-1.0 API/TODO, rootBundle initialization, culture database/assets와 더 넓은 dependency surface, 비교적 작은 adoption.
- privacy/security: local assets이지만 Flutter Web asset fetch/cache behavior와 추가 `http`/`universal_io` surface를 검토해야 한다.
- migration/compatibility: package type가 domain 전체로 퍼지면 교체 비용이 커질 수 있다.
- 운영/비용: 현재 one-time/recurrence subset보다 큰 API와 initialization surface다.

### Option C — Dart core `DateTime` 또는 server-only conversion

- 장점: client runtime dependency가 없다.
- 단점: client에서 IANA zone/gap/fold를 표현하거나 deterministic preview할 수 없고 device timezone이 섞이기 쉽다.
- privacy/security: 추가 surface는 없지만 잘못된 시간 저장이 reliability/data integrity 위험이다.
- migration/compatibility: 잘못 materialized된 occurrence를 나중에 복구하기 어렵다.
- 운영/비용: support와 repair 비용이 가장 크다.

## Decision

1. client adapter는 exact `timezone: 0.11.1`을 사용한다. dependency import는 calendar data layer에만 둔다.
2. local date/time, UTC instant, IANA ID, all-day range와 zoned intent는 KinFlow domain type으로 소유한다. package type를 repository/UI contract에 노출하지 않는다.
3. canonical storage instant는 PostgreSQL private resolver 결과가 authority다. client result는 form preview와 deterministic validation 보조다.
4. timed input은 minute precision이다. event timezone은 생성 시 pinned되고 device/household timezone 변경으로 silent mutation하지 않는다.
5. nonexistent DST gap은 `reject`한다. 다음 유효 시각으로 자동 이동하지 않는다.
6. ambiguous DST overlap은 default `earlier` instant를 선택하며 request가 `later`를 명시할 수 있다. policy와 resolved kind는 persistence contract에 포함한다.
7. all-day는 `[startDate, endDateExclusive)` date-only 값이며 UTC instant 또는 timezone을 저장하지 않는다.
8. client/server timezone database version은 release artifact에서 확인한다. current IANA와 차이가 calendar 결과에 영향을 줄 수 있으면 dependency/image upgrade 전 production feature를 enable하지 않는다.

## Consequences

### Positive

- DST gap/fold를 silent normalization 없이 사용자 intent와 별도 상태로 다룬다.
- package 교체가 data adapter에 국한되고 server authority와 wire contract는 유지된다.
- Android, future Web/iOS가 같은 exact date/time/zone/policy schema를 공유한다.
- all-day travel semantics가 timed instant 계산과 분리된다.

### Negative / Debt

- client bundled TZDB와 PostgreSQL deployment tzdata가 current IANA보다 뒤거나 서로 다를 수 있다.
- client preview와 server result가 다른 경우 server result를 다시 표시하고 사용자 확인 UX가 필요하다.
- `timezone`은 LocalDate/LocalTime typed policy를 제공하지 않으므로 adapter candidate mapping을 KinFlow가 유지한다.
- minute candidate scan을 사용하는 initial PostgreSQL helper는 create/edit에 적합하지만 bulk recurrence materializer 전에 query plan/optimized algorithm을 다시 검토해야 한다.

## Implementation

- schema/API/module: private PostgreSQL resolver, calendar domain primitives/service interface, timezone data adapter.
- feature flag: user-visible Calendar는 WP04-02 전 production OFF 상태를 유지한다.
- migration: additive private function만 추가하며 event table은 WP04-02다.
- observability: raw timezone input/error를 log하지 않고 allowlisted error code와 DB version만 기록한다.
- manual setup: 없음. OS calendar/contact permission을 요청하지 않는다.

## Validation

- automated tests: TIME-001~008, 011, 014와 leap/year boundary client unit + PostgreSQL integration parity.
- manual/device tests: Android picker/device travel/tzdata version은 WP04-02 이후 마지막 실제 기기 gate로 연기한다.
- evidence: `docs/evidence/phase-04/WP04_01_EVIDENCE.md`.

## Rollback / Revisit Trigger

- rollback: user-visible event create를 disable하고 adapter/dependency를 제거한다. applied DB migration은 forward corrective migration으로 function을 대체한다.
- 재검토: package abandoned/security issue, client/server parity failure, IANA change affecting supported scheduling window, recurrence materializer performance failure 또는 Web asset size regression.

## Platform Impact (v1.0)

- target platforms: shared domain + Android client + PostgreSQL server; future Web/iOS compatible contract.
- capability interface/provider: domain `CalendarTimeResolver` / data `TimezoneCalendarTimeResolver`.
- unsupported fallback: unknown/stale zone 또는 gap은 저장하지 않고 stable validation failure를 반환한다.
- mobile release impact: no native permission or plugin; embedded Dart data size만 증가한다.
- Web Beta/GA impact: adapter import/asset strategy와 build size를 Web scaffold gate에서 별도 검증한다.
- native/Web rollback differences: domain/server contract는 동일하고 adapter initialization/build packaging만 플랫폼별로 교체한다.

## Sources reviewed on 2026-08-07

- <https://pub.dev/packages/timezone>
- <https://pub.dev/documentation/timezone/latest/timezone/>
- <https://pub.dev/packages/time_machine2>
- <https://www.iana.org/time-zones>
