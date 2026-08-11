# 원본 파일 문서화: `contracts/calendar-file-import.yaml`

> 이 파일은 Android `.ics` 단방향 가져오기의 WP04-13 normative 계약을 Markdown 코드 블록으로 보존합니다.

- 구현 시 생성할 원본 경로: `contracts/calendar-file-import.yaml`
- 원본 형식: `yaml`
- 범위: WP04-13, FR-CAL-009, CAP-019, D-059

```yaml
version: "2026-08-09-wp04-13"
requirements: [FR-CAL-009, FR-CAL-001, FR-CAL-002, FR-CAL-003, FR-CAL-004, NFR-SEC-01, NFR-PRIV-01, NFR-REL-01, NFR-A11Y-01, NFR-I18N-01, D-059]
product:
  operation: explicit one-way copy into the active KinFlow household
  source: one user-selected UTF-8 iCalendar file
  previewRequired: true
  eventSelection: one or more supported candidates
  participantSelection: one common non-empty active-household member set for the batch
  duplicateDisclosure: reimporting the same file can create new copies
  synchronization: none
platform:
  initial: Android Storage Access Framework ACTION_OPEN_DOCUMENT
  permission: no calendar permission and no broad storage permission
  mimeTypes: [text/calendar, application/ics, application/octet-stream]
  cancellation: return a typed cancelled result without an error banner
  unavailable: fail closed with a localized recovery message
input:
  encoding: strict UTF-8
  maximumBytes: 262144
  maximumVevents: 50
  lineEndings: CRLF or LF accepted at the trust boundary
  folding: one leading SPACE or HTAB continues the previous content line
  structure:
    - exactly one outer VCALENDAR
    - exactly one VERSION:2.0
    - no nested or mismatched components
    - VEVENT must contain one UID, DTSTART and non-empty SUMMARY
  lifecycle: source content and display name remain process-memory only and are never logged, cached, persisted or sent to analytics
event:
  importedText:
    summary: RFC TEXT unescape then existing title bounds
    description: RFC TEXT unescape then existing description bounds
    ignored: [LOCATION, URL, ORGANIZER, ATTENDEE, ATTACH, VALARM, unknown extension properties]
  allDay:
    start: DTSTART VALUE=DATE YYYYMMDD
    end: DTEND VALUE=DATE exclusive, or one day when absent
    duration: positive whole-day or whole-week RFC duration that remains inside the supported 0001..9999 local-date range
  timed:
    format: YYYYMMDDTHHMMSS with seconds exactly 00
    zones:
      utcZ: imported in UTC
      floating: interpreted in the active household IANA timezone with an explicit preview disclosure
      tzid: exact bundled IANA timezone only
    end: matching-zone positive DTEND or positive minute-aligned RFC DURATION; day/week components advance nominal local calendar days before exact hour/minute components
    maximumDurationMinutes: 10080
    dstGap: skip the event
    dstOverlap: use existing earlier policy and disclose it in the preview
  unsupportedPerEvent:
    - invalid or duplicate required properties
    - RECURRENCE-ID, EXDATE, RDATE or multiple RRULE
    - DTSTART and DTEND value-kind or timezone mismatch
    - unsupported timezone, second precision, overflowing date or unbounded duration
recurrence:
  optionalProperty: one RRULE
  frequency: [DAILY, WEEKLY, MONTHLY]
  interval: 1..30, default 1
  end:
    never: no COUNT or UNTIL
    count: 1..1000
    until: VALUE=DATE all-day recurrence only and not before DTSTART
  weekly:
    byday: optional unique unnumbered weekday list; defaults to DTSTART weekday
    anchor: DTSTART weekday must be included
  monthly:
    bymonthday: absent or exactly DTSTART day
    missingDate: skip, never clamp
  rejected: [YEARLY, BYSETPOS, ordinal BYDAY, BYMONTH, BYWEEKNO, BYYEARDAY, BYHOUR, BYMINUTE, BYSECOND, WKST]
parseResult:
  fatal: invalid file encoding, size, calendar structure, version or VEVENT count
  supported: canonical candidates with source UID discarded after within-file duplicate detection
  skipped: aggregate counts for invalid, unsupported and duplicate events; no raw source content in failures
mutation:
  authority: existing create_one_time_calendar_event and create_recurring_calendar_event RPC contracts
  runtimeGuard: calendar mutation policy must pass before picker, command ID, repository or network I/O
  order: preview order, sequential one command at a time
  retry: generate and freeze one idempotency key per selected candidate before first write; stop on first failure and reuse the same failed key on retry
  partialFailure: keep completed count and remaining in process memory; already-created events remain authoritative
  navigation: user back/close is blocked only while the sequential batch is actively writing; disposal or auth/context invalidation stops before the next command
  processDeath: no batch resume because persisting external family content is forbidden in this slice
  success: discard source content, return to Calendar and refresh
security:
  externalUid: within-file duplicate detection only; never display, log, persist or send
  uri: native-only transient handle; never return to Dart
  sourceActions: no URL open, attachment read, alarm execution or provider callback
  serverAuthority: existing household membership, participant, time and recurrence validation remains authoritative
rollback:
  client: remove the import route/action, gateway and parser
  server: none because schema, RPC, RLS and migrations are unchanged
deferred:
  - Google, Apple or CalDAV account connection
  - automatic refresh, update/delete propagation and two-way sync
  - persistent source UID deduplication
  - custom VTIMEZONE rules, exceptions and broader recurrence grammar
  - iOS and Web file pickers
  - hosted, real-account, multi-device and physical-device evidence
```
