# 원본 파일 문서화: `contracts/calendar-weekly-weekdays.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/calendar-weekly-weekdays.yaml`
- 원본 형식: `yaml`
- 범위: WP04-11 Calendar weekly multiple-weekday selection for creation and whole-series edit

```yaml
version: "2026-08-09-wp04-11"
requirements: [FR-CAL-004, FR-CAL-006, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-019, D-020]
scope:
  surfaces: [calendar event creation, whole recurring-series edit, recurring event summary]
  frequency: weekly only
  serverSchema: unchanged existing strict recurrence rule
rule:
  weekdays:
    type: unique non-empty array
    values: [MO, TU, WE, TH, FR, SA, SU]
    minimumItems: 1
    maximumItems: 7
    serializationOrder: ISO weekday order from Monday through Sunday
  anchorInvariant: selected weekdays MUST contain the edited event local start-date weekday
creation:
  initialSelection: exact event local start-date weekday
  selection: user MAY add or remove any non-anchor weekday
  startDateChange: keep selected weekdays and add the new start-date weekday if absent
seriesEdit:
  unchangedWeeklyFrequency: prefill the full active rule weekday set
  changedToWeekly: initialize with the active revision event local start-date weekday
  startDateChange: keep selected weekdays and add the new start-date weekday if absent
  effects: existing immutable revision, future non-exception rebuild, past and explicit-exception preservation
frequencyTransition:
  awayFromWeekly: do not serialize weekdays
  backToWeeklyWithinEditor: restore the in-progress selected set and enforce the current start-date anchor
command:
  authority: existing create_recurring_calendar_event and update_recurring_calendar_series RPCs
  overlapPreview: exact edited full rule including canonical weekday array
  retry: changed weekday set changes the draft fingerprint and receives a new idempotency key
  invalidInput: no overlap preview, command-ID, repository or network call
presentation:
  controls: seven localized toggle chips in ISO weekday order
  anchor: current start-date weekday remains selected and cannot be deselected
  helper: explain why the anchor weekday is required
  summary: localized selected weekday list in the editor and recurring event card
  accessibility: scrollable compact layout, 48dp tap targets, selected state, labels and live summary
  localization: [EN, KO, EN-XA]
security:
  rawErrorText: forbidden
  runtimeGuard: existing exact calendar feature guard remains before repository, ID or network I/O
  clientAuthority: advisory validation only; existing database rule and server-local-date validation remain authoritative
rollback:
  client: hide weekday toggles and return to the start-date-only weekly anchor
  server: none because no schema, RPC, RLS or migration changes
deferred:
  - multiple month days and ordinal weekdays
  - yearly, business-day and exception-calendar rules
  - selected-boundary edit and cancellation are defined by WP04-14 and WP04-15
  - real-account, hosted Supabase, two-device and physical-device evidence
```
