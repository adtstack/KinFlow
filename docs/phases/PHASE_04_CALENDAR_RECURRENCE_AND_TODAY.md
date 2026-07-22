# Phase 04 — 공유 일정, 반복, 시간대, Today 통합

## 목표

가족이 종일/시간 지정 일정을 공유하고 반복·예외·참석자를 관리하며, 시간대와 DST에서도 정확한 occurrence를 Today에 통합한다.

## Entry

Chores Value Gate 통과, recurrence time library ADR 승인.

## Work Packages

### WP04-01 Time primitives

- Instant/LocalDate/LocalTime/IANA timezone
- all-day exclusive date range
- DST gap/overlap policy
- serialization contract

### WP04-02 One-time event

- create/edit/delete
- timed/all-day
- household participants
- validation/RLS

### WP04-03 Calendar views

- PRD가 정한 day/month/list scope
- compact/tablet adaptive
- locale first day/date formatting
- accessible navigation

### WP04-04 Recurring event

- series/revision/occurrence/exception
- single edit/cancel
- future/whole series edit
- completed/past preservation policy

### WP04-05 Today integration

- chores/events combined sections
- same household local date
- deterministic ordering
- performance/cache invalidation

### WP04-06 Conflict/concurrency

- expected version
- concurrent edits
- deleted/stale deep link
- Realtime reconnect

## 자동 검증

- TIME_RECURRENCE_TEST_MATRIX 전부
- participant household integrity/RLS
- all-day round trip
- materialization idempotency
- Today cross-context order
- serialization locale independence

## 수동 검증

- DST 대표 timezone device tests
- device timezone travel change
- iOS/Android date picker
- iPad split view
- two-device concurrent edit

## Exit Gate

one-time/recurring/all-day event가 시간대 정책에 따라 안정적으로 표시되고 single occurrence와 series 수정 의미가 분리된다.

## Stop/Rollback

DST fixture 또는 과거 occurrence 보존 실패 시 반복 일정 출시 금지. one-time event만 feature flag로 유지 가능해야 한다.
