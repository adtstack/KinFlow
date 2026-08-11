# 원본 파일 문서화: `contracts/chore-advanced-recurrence.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/chore-advanced-recurrence.yaml`
- 원본 형식: `yaml`
- 범위: WP03-14 repeating chore interval and end controls for creation and future-series edit

```yaml
version: "2026-08-09-wp03-14"
requirements: [FR-CHORE-005, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-017]
scope:
  surfaces: [chore creation, future repeating-series edit]
  frequencies: [daily, weekly, monthly]
  guidedSetup: delegated to the WP03-17 guided advanced recurrence contract
  serverSchema: unchanged existing recurrence rule
rule:
  interval:
    type: integer
    minimum: 1
    maximum: 30
  end:
    variants:
      never: {exactKeys: [type]}
      count: {exactKeys: [type, count], minimum: 1, maximum: 1000}
      until: {exactKeys: [type, localDate], minimum: start or effective household local date}
  anchor:
    creation:
      daily: no additional field
      weekly: exact start-date weekday
      monthly: exact start-date month day
    seriesEdit:
      unchangedFrequency: preserve existing weekdays or month day
      changedFrequency: anchor to server-authoritative household effective local date
creation:
  authority: existing create_repeating_chore RPC
  request: full strict ChoreRecurrenceRule instead of client-fixed interval one and never end
  retry: changed interval or end changes the fingerprint and receives a new idempotency key
  invalidInput: no repository or command-ID call
seriesEdit:
  authority: existing update_repeating_chore_series RPC
  effectiveDate: current server-authoritative household local date
  effects: existing future incomplete occurrence rebuild and past/completed preservation
  conflict: existing expected-version and same-key retry contract
presentation:
  controls:
    - frequency
    - interval bounded numeric input
    - end mode
    - bounded occurrence count when count mode is selected
    - household-local end date picker when until mode is selected
  summary: localized frequency, interval, anchor date and end condition
  accessibility: scrollable compact layout, 48dp actions, labels, validation, live summary
  localization: [EN, KO, EN-XA]
security:
  rawErrorText: forbidden
  runtimeGuard: exact chores feature before repository, ID or network I/O
  clientAuthority: advisory validation only; existing database rule validator remains authoritative
rollback:
  client: hide advanced controls and return to interval one plus never end
  server: none because no schema, RPC, RLS or migration changes
deferred:
  - multiple weekdays in one weekly rule
  - multiple month days or ordinal weekday rules
  - yearly, business-day and exception-calendar recurrences
  - real-account, hosted Supabase, two-device and physical-device evidence
```
