# 원본 파일 문서화: `contracts/time-primitives.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/time-primitives.yaml`
- 원본 형식: `yaml`
- 관련 범위: WP04-01, FR-CAL-001, FR-CAL-002, FR-CAL-004, FR-TODAY-001
- 공개 API 주의: `KFT01`/`KFT02`는 private PostgreSQL helper의 내부 SQLSTATE이며 WP04-02 공개 RPC가 stable error catalog로 매핑한다.

```yaml
version: "2026-08-07"
authority:
  canonicalPersistenceInstant: PostgreSQL resolver
  clientResolution: preview and validation only
  clientClock: never authoritative
  deviceTimezone: presentation context only

primitives:
  localDate:
    format: YYYY-MM-DD
    calendar: proleptic Gregorian
    yearRange: 0001..9999
    timezoneFree: true
  localTime:
    format: HH:mm
    precision: minute
    range: 00:00..23:59
    timezoneFree: true
  utcInstant:
    format: RFC3339 UTC with literal Z
    precision: second through microsecond
    rejectOffsetsOtherThanZ: true
  ianaTimezone:
    accepted: UTC or canonical area/location identifier
    maxLength: 100
    caseSensitive: true
    rejectAbbreviations: true
    requireResolverDatabaseMembership: true

payloads:
  calendarAllDayRangeV1:
    exactKeys: [startDate, endDateExclusive]
    startDate: localDate, inclusive
    endDateExclusive: localDate, exclusive and later than startDate
    forbiddenKeys: [timezone, startAt, endAt, utcOffset]
  calendarZonedDateTimeIntentV1:
    exactKeys: [localDate, localTime, timezone, gapPolicy, overlapPolicy]
    localDate: localDate
    localTime: localTime
    timezone: ianaTimezone pinned to event intent
    gapPolicy: reject
    overlapPolicy: earlier | later
    defaultOverlapPolicy: earlier
    forbiddenKeys: [deviceTimezone, utcOffset]
  calendarResolvedTimeV1:
    fields:
      resolvedAt: utcInstant
      utcOffsetSeconds: signed integer selected by resolver
      resolution: normal | overlap_earlier | overlap_later
      candidateCount: positive integer
    invariants:
      - normal requires candidateCount = 1.
      - overlap_earlier and overlap_later require candidateCount >= 2.
      - resolvedAt projected through timezone MUST reproduce localDate and localTime exactly.
  calendarRecurrenceEndV1:
    variants:
      never:
        exactKeys: [type]
        type: never
      count:
        exactKeys: [type, count]
        type: count
        count: integer 1..1000
      until:
        exactKeys: [type, localDate]
        type: until
        localDate: inclusive localDate
  calendarRecurrenceRuleV1:
    common:
      frequency: daily | weekly | monthly
      interval: integer 1..30
      end: calendarRecurrenceEndV1
    variants:
      daily:
        exactKeys: [frequency, interval, end]
      weekly:
        exactKeys: [frequency, interval, weekdays, end]
        weekdays: unique non-empty array of MO | TU | WE | TH | FR | SA | SU
        anchorInvariant: weekdays MUST contain the source localDate weekday
      monthly:
        exactKeys: [frequency, interval, monthDay, end]
        monthDay: integer 1..31
        anchorInvariant: monthDay MUST equal the source localDate day
        missingDatePolicy: skip the month; do not clamp to its last day
    forbiddenKeys: [locale, localizedWeekday, deviceTimezone, resolvedAt, utcOffset]
    untilInvariant: until.localDate MUST NOT precede the source localDate

dstPolicy:
  nonexistentGap:
    behavior: reject
    silentShiftForward: forbidden
  ambiguousOverlap:
    behavior: select explicit policy
    earlier: chronologically first matching instant
    later: chronologically last matching instant
    persistPolicyAndResolution: true

allDayPolicy:
  storage: date-only half-open range
  utcMidnightConversion: forbidden
  timezoneProjection: forbidden
  travelBehavior: dates remain unchanged

rules:
  - Timed event intent MUST retain localDate, localTime, pinned timezone, gapPolicy, and overlapPolicy separately from the resolved UTC instant.
  - A household, device, locale, or travel timezone change MUST NOT silently mutate event intent.
  - Unknown timezone identifiers and non-minute local times MUST fail closed before persistence.
  - The PostgreSQL resolver result MUST replace any disagreeing client preview before persistence.
  - Locale-dependent strings MUST NOT cross repository, RPC, or database boundaries.
  - Recurrence materialization MUST resolve each occurrence from its local intent; it MUST NOT add fixed UTC durations across DST.
  - Recurrence count means actual matching local dates; skipped monthly dates do not consume count.
  - A materialization replay for the same series and recurrence local date MUST reuse the unique occurrence slot rather than insert a duplicate.

privateDatabaseBoundary:
  function: app_private.resolve_calendar_zoned_datetime(date, time, text, text)
  callableByApiRoles: false
  invalidInputSqlstate: KFT01
  nonexistentLocalTimeSqlstate: KFT02
  publicErrorMapping: deferred to WP04-02

timezoneDataReleaseGate:
  clientAdapter: timezone 0.11.1
  clientBundledDatabase: 2025c
  comparisonBaselineOnDecisionDate: IANA 2026c
  requirements:
    - Record client and deployed PostgreSQL timezone database versions for each Calendar release candidate.
    - Re-run client/server parity fixtures when either timezone database changes.
    - Keep Calendar production-disabled when drift changes an instant in the supported scheduling window.
```
