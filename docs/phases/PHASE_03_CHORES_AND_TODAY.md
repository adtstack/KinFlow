# Phase 03 — 집안일과 Today

## 목표

가족이 집안일을 만들고 담당자·마감·반복을 지정하고, Today에서 확인·완료하며 다른 기기와 안전하게 동기화한다.

## Entry

Household Alpha Gate 통과.

## Work Packages

### WP03-01 Chore domain/schema

- series/revision/occurrence 기본 모델
- title/assignee/due/local intent/state
- household integrity/RLS
- domain state transition

### WP03-02 One-time chore

- create/edit/cancel/detail/list
- server validation/error mapping
- adaptive form/UI

### WP03-03 Assignment and members

- adult/managed assignee
- removed/suspended member behavior
- cross-household FK attack

### WP03-04 Completion

- expected version/idempotency
- complete/uncomplete/optional approval 범위
- actor/acting child audit
- duplicate tap/conflict

### WP03-05 Repeating chore

- supported recurrence subset
- revision/occurrence materialization
- single occurrence and future series edit
- time matrix fixtures

### WP03-06 Today chores

- household date/timezone
- ordering/filter/empty/error/stale
- Realtime invalidation or resume refetch
- performance budget

### WP03-07 Notification event hooks

실제 push 전에 due/assignment domain event와 inbox contract를 기록한다.

## 자동 검증

- domain transition
- RLS CRUD/assignment
- recurrence fixtures
- idempotency/version conflict
- Today query/order/pagination
- widget/a11y/large text

## 수동 검증

- two-device assignment/complete
- managed child completion
- timezone/date boundary
- reinstall/resume
- iPad/Android tablet layout

## Exit Gate

두 가족 구성원이 반복 집안일을 만들고 담당하고 완료한 상태가 양쪽 Today에 일관되게 보인다. 완료 history와 recurrence definition이 분리되어 있다.

## Rollback

recurrence를 feature flag off하고 one-time chore를 유지할 수 있어야 한다. materialization repair script와 audit가 준비되어야 한다.
