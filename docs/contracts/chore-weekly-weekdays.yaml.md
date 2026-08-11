# 원본 파일 문서화: `contracts/chore-weekly-weekdays.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/chore-weekly-weekdays.yaml`
- 원본 형식: `yaml`
- 범위: WP03-15 Chore weekly multiple-weekday selection for creation and future-series edit

```yaml
version: "2026-08-09-wp03-15"
requirements: [FR-CHORE-005, FR-CHORE-008, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-017]
scope:
  surfaces: [recurring chore creation, future recurring-series edit]
  frequency: weekly only
  serverSchema: unchanged existing strict recurrence rule
rule:
  weekdays:
    type: unique non-empty array
    values: [MO, TU, WE, TH, FR, SA, SU]
    minimumItems: 1
    maximumItems: 7
    serializationOrder: ISO weekday order from Monday through Sunday
creation:
  initialSelection: exact start_local_date weekday
  anchorInvariant: selected weekdays MUST contain the start_local_date weekday
  selection: user MAY add or remove any non-anchor weekday
  startDateChange: keep selected weekdays and add the new start-date weekday if absent
  templateApplication: reset to the current start-date weekday only
seriesEdit:
  boundary: existing server-authoritative household effective local date
  unchangedWeeklyFrequency: prefill the full active rule weekday set
  changedToWeekly: initialize with the household effective local-date weekday
  selection: user MAY add or remove weekdays while at least one remains
  anchorInvariant: none because update_repeating_chore_series accepts any non-empty weekly set
  effects: existing immutable revision, future incomplete rebuild, past and completed preservation
frequencyTransition:
  awayFromWeekly: do not serialize weekdays
  backToWeeklyWithinEditor: restore the in-progress selected set; if empty initialize the surface-specific default
command:
  authority: existing create_repeating_chore and update_repeating_chore_series RPCs
  retry: changed weekday set changes the draft or update fingerprint and receives a new idempotency key
  invalidInput: no command-ID, repository or network call
presentation:
  controls: seven localized toggle chips in ISO weekday order
  creationAnchor: current start-date weekday remains selected and cannot be deselected
  seriesMinimum: the final selected weekday cannot be deselected
  helper: explain the surface-specific locked selection rule
  summary: localized selected weekday list in the recurrence editor
  accessibility: compact wrapping layout, 48dp tap targets, selected state, labels and live summary
  localization: [EN, KO, EN-XA]
security:
  rawErrorText: forbidden
  runtimeGuard: existing exact chores feature guard remains before repository, ID or network I/O
  clientAuthority: advisory validation only; existing database rule and server-local-date boundary remain authoritative
rollback:
  client: hide weekday toggles and return to the start-date-only weekly creation rule and anchor-preserving series editor
  server: none because no schema, RPC, RLS or migration changes
deferred:
  - multiple month days and ordinal weekdays
  - yearly, business-day and exception-calendar rules
  - real-account, hosted Supabase, two-device and physical-device evidence
```
