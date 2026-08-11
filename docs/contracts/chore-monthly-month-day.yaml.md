# 원본 파일 문서화: `contracts/chore-monthly-month-day.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/chore-monthly-month-day.yaml`
- 원본 형식: `yaml`
- 범위: WP03-16 Chore monthly day-of-month selection for creation and future-series edit

```yaml
version: "2026-08-09-wp03-16"
requirements: [FR-CHORE-005, FR-CHORE-008, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-017]
scope:
  surfaces: [recurring chore creation, future recurring-series edit]
  frequency: monthly only
  serverSchema: unchanged existing strict recurrence rule
rule:
  monthDay:
    type: integer
    minimum: 1
    maximum: 31
  missingDatePolicy: skip the month; never clamp to its final day
  countSemantics: only materialized matching local dates consume count
creation:
  initialSelection: exact start_local_date day
  anchorInvariant: monthDay MUST equal the start_local_date day
  selection: displayed but locked because changing the due date changes the anchor
  startDateChange: replace the displayed and serialized monthDay with the new day
  templateApplication: use the current start_local_date day
seriesEdit:
  boundary: existing server-authoritative household effective local date
  unchangedMonthlyFrequency: prefill the active rule monthDay exactly
  changedToMonthly: initialize with the household effective local-date day
  selection: user MAY select any integer from 1 through 31
  anchorInvariant: none because update_repeating_chore_series accepts a monthly rule independent of the effective boundary date
  effects: existing immutable revision, future incomplete rebuild, past and completed preservation
frequencyTransition:
  awayFromMonthly: do not serialize monthDay
  backToMonthlyWithinEditor: restore the in-progress selected monthDay
command:
  authority: existing create_repeating_chore and update_repeating_chore_series RPCs
  retry: changed monthDay changes the draft or update fingerprint and receives a new idempotency key
  invalidInput: no command-ID, repository or network call
presentation:
  control: localized day-of-month dropdown with values 1 through 31
  creationAnchor: control is disabled and helper explains that the first due date owns the value
  seriesSelection: control is enabled
  missingDateHelper: explain that months without the selected date are skipped and never moved to the last day
  summary: localized selected month day in the recurrence editor live summary
  accessibility: expanded dropdown, ellipsis-safe menu labels, form label and live summary
  localization: [EN, KO, EN-XA]
security:
  rawErrorText: forbidden
  runtimeGuard: existing exact chores feature guard remains before repository, ID or network I/O
  clientAuthority: advisory validation only; existing database rule and server-local-date boundary remain authoritative
rollback:
  client: hide the month-day control and return to due-date-derived creation and saved-anchor-preserving series behavior
  server: none because no schema, RPC, RLS or migration changes
deferred:
  - multiple month days, last-day and ordinal-weekday recurrence schemas
  - yearly, business-day and exception-calendar rules
  - real-account, hosted Supabase, two-device and physical-device evidence
```
