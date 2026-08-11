# 원본 파일 문서화: `contracts/calendar-advanced-recurrence.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/calendar-advanced-recurrence.yaml`
- 원본 형식: `yaml`
- 범위: WP04-10 recurring Calendar interval and end controls for creation and whole-series edit

```yaml
version: "2026-08-09-wp04-10"
requirements: [FR-CAL-004, FR-CAL-006, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-019, D-020]
scope:
  surfaces: [calendar event creation, whole recurring-series edit]
  frequencies: [daily, weekly, monthly]
  occurrenceEdit: unchanged single-occurrence exception content only
  serverSchema: unchanged existing strict recurrence rule
rule:
  interval:
    type: integer
    minimum: 1
    maximum: 30
  end:
    variants:
      never: {exactKeys: [type]}
      count: {exactKeys: [type, count], minimum: 1, maximum: 1000}
      until: {exactKeys: [type, localDate]}
    creationMinimum: event local start date
    seriesEditMinimum: maximum of active revision local start date and server-returned household local date
  anchor:
    creation:
      daily: no additional field
      weekly: exact event local start-date weekday
      monthly: exact event local start-date month day
    seriesEdit:
      unchangedFrequency: preserve existing weekdays or month day
      changedFrequency: anchor to active revision event local start date
creation:
  authority: existing create_recurring_calendar_event RPC
  request: full strict CalendarRecurrenceRule instead of client-fixed interval one and never end
  retry: changed interval or end changes the draft fingerprint and receives a new idempotency key
  invalidInput: no overlap preview, command-ID, repository or network call
seriesEdit:
  authority: existing update_recurring_calendar_series RPC
  effectiveBoundary: server-derived household local today remains authoritative
  effects: existing immutable revision, future non-exception rebuild, past and explicit-exception preservation
  conflict: existing expected-version, same-key retry and authoritative reload contract
overlapPreview:
  authority: existing preview_calendar_event_overlaps RPC
  recurrence: exact edited full rule
  invalidInput: suppress preview instead of degrading to a one-time candidate
presentation:
  controls:
    - frequency or one-time selection on creation
    - interval bounded numeric input for a recurring selection
    - end mode
    - bounded occurrence count when count mode is selected
    - household-local end date picker when until mode is selected
  summary: localized frequency, interval, event anchor date and end condition
  card: localized frequency with non-default interval
  accessibility: scrollable compact layout, 48dp actions, labels, validation, live summary
  localization: [EN, KO, EN-XA]
security:
  rawErrorText: forbidden
  runtimeGuard: existing exact calendar feature guard remains before repository, ID or network I/O
  clientAuthority: advisory validation only; existing database rule and server-local-date validation remain authoritative
rollback:
  client: hide interval and end controls and return to interval one plus never end
  server: none because no schema, RPC, RLS or migration changes
deferred:
  - selecting multiple weekdays or multiple month days
  - ordinal weekday, yearly, business-day and exception-calendar rules
  - selected-boundary edit and cancellation are defined by WP04-14 and WP04-15
  - real-account, hosted Supabase, two-device and physical-device evidence
```
