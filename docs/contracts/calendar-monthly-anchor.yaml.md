# 원본 파일 문서화: `contracts/calendar-monthly-anchor.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/calendar-monthly-anchor.yaml`
- 원본 형식: `yaml`
- 범위: WP04-12 Calendar monthly start-date anchor synchronization for creation and whole-series edit

```yaml
version: "2026-08-09-wp04-12"
requirements: [FR-CAL-004, FR-CAL-006, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-019, D-020]
scope:
  surfaces: [calendar event creation, whole recurring-series edit, recurring event summary]
  frequency: monthly only
  serverSchema: unchanged existing strict recurrence rule
rule:
  monthDay:
    type: integer
    minimum: 1
    maximum: 31
  anchorInvariant: monthDay MUST equal the edited event local start-date day
  missingDatePolicy: skip the month; never clamp to its final day
  countSemantics: only materialized matching local dates consume count
creation:
  initialValue: exact event local start-date day
  selection: displayed but locked because the start date owns the value
  startDateChange: replace the displayed, previewed and serialized monthDay with the new day
seriesEdit:
  unchangedMonthlyFrequency: prefill the active rule, then re-anchor to the edited event local start date
  changedToMonthly: initialize from the active revision event local start-date day
  startDateChange: replace monthDay while preserving interval and end
  effects: existing immutable revision, future non-exception rebuild, past and explicit-exception preservation
frequencyTransition:
  awayFromMonthly: do not serialize monthDay
  backToMonthlyWithinEditor: derive monthDay from the current edited start date
command:
  authority: existing create_recurring_calendar_event and update_recurring_calendar_series RPCs
  overlapPreview: exact edited full rule with the current start-date-derived monthDay
  retry: changed start date changes the event and recurrence fingerprints and receives a new idempotency key
  invalidInput: no overlap preview, command-ID, repository or network call
presentation:
  control: localized disabled day-of-month dropdown with values 1 through 31
  anchorHelper: explain that changing the event start date changes the monthly day
  missingDateHelper: explain that months without the selected date are skipped and never moved to the final day
  summary: localized selected month day in the editor live region and recurring event card
  accessibility: expanded dropdown, ellipsis-safe labels, helper text and live summary
  localization: [EN, KO, EN-XA]
security:
  rawErrorText: forbidden
  runtimeGuard: existing exact calendar feature guard remains before repository, ID or network I/O
  clientAuthority: advisory validation only; existing database rule, start-anchor check and server-local-date series boundary remain authoritative
rollback:
  client: hide the month-day control and keep deriving the monthly anchor from the edited start date
  server: none because no schema, RPC, RLS or migration changes
deferred:
  - independently selectable and multiple month dates
  - last-day, ordinal-weekday, yearly, business-day and exception-calendar rules
  - selected-boundary edit and cancellation are defined by WP04-14 and WP04-15
  - real-account, hosted Supabase, two-device and physical-device evidence
```
