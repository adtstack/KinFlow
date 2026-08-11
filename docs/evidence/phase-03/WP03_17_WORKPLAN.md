# Phase 03 WP03-17 Guided Advanced Recurrence Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- Phase: 03 only
- Vertical slice: exact-three guided chore selection → full supported recurrence editing → secure frozen-batch resume → existing recurring create

## Requirements and decisions

- Requirements: FR-CHORE-005, FR-CHORE-010, NFR-REL-01, NFR-PRIV-01, NFR-A11Y-01, NFR-I18N-01
- Decisions: D-019, D-048, D-051
- Contract: docs/contracts/guided-chore-advanced-recurrence.yaml.md
- Test IDs: T-CHORE-01, T-CHORE-RECURRENCE-EDITOR, T-CHORE-WEEKDAYS, T-CHORE-MONTH-DAY, T-GUIDED-RESUME, T-I18N-01, T-A11Y-03

## Scope

1. 첫 가구 빠른 설정의 각 선택 항목에서 daily, weekly, monthly와 interval 1..30을 편집한다.
2. never, count 1..1000, until 종료 조건을 기존 ChoreRecurrenceEditor로 제공한다.
3. weekly는 frozen start weekday를 잠근 채 ISO 순서의 추가 요일을 선택한다.
4. monthly는 frozen start date day를 잠긴 기준일로 사용하고 없는 달은 skip한다.
5. full recurrence rule을 draft fingerprint, secure submitted batch와 retry payload에 보존한다.
6. secure resume schema를 v2 exact recurrenceRule로 올리고 v1 record는 재생하지 않고 정리한다.
7. 제출 전 편집 상태는 계속 저장하지 않으며 제출 뒤에는 전체 draft를 잠근다.

## DB, API, and storage impact

- PostgreSQL migration, RLS, RPC, Edge Function, OpenAPI, remote DTO: **변경 없음**
- 기존 create recurring chore signature와 server authority: **변경 없음**
- local secure storage: submitted guided batch key/schema v1 → v2
- v1 data migration: **없음**. 오래된 미완료 batch는 read/clear 시 안전하게 삭제한다.
- 새 runtime dependency와 native permission: **변경 없음**

## Security and privacy

- title, recurrence payload, template key, command ID와 household/member ID를 log나 analytics에 추가하지 않는다.
- invalid rule은 command ID 생성, secure write와 repository 호출 전에 차단한다.
- secure record는 exact keys, size, scope, full domain rebuild와 canonical encoding을 검증한다.
- corrupt, unknown version, v1 또는 scope mismatch record는 UI에 raw detail 없이 정리한다.
- server의 membership, household, entitlement와 recurrence validation은 계속 최종 authority다.

## Automated verification

- domain exact-three ordering과 full daily/weekly/monthly recurrence fidelity
- weekly required start anchor, monthly start-day anchor와 invalid end rejection
- full-rule fingerprint 변화와 exact retry command ID reuse
- secure v2 round trip, canonical recurrence JSON, v1 cleanup, corrupt/scope/size purge
- widget monthly, interval/count, weekly multiple-day mapping과 frozen resume restoration
- compact EN-XA 320×568 200% scroll 및 48dp action
- focused, impact, full Flutter regression, analyzer, format, codegen, config, secret and documentation gates

## Manual and deferred verification

- remote Supabase materialization과 real account exact-three creation
- two-device retry/concurrency and process-kill Keystore recovery
- Android date picker, TalkBack and physical phone/tablet layout
- schema 밖의 multiple month dates, last-day, ordinal, yearly/business-day recurrence

사용자 지시에 따라 remote, 실계정, 다중기기와 실기기 검증은 마지막 통합 Gate까지 미룬다.

## Rollback

- advanced editor를 숨기고 interval 1, never ending daily/weekly suggestion으로 돌아갈 수 있다.
- rollback 전에 v2 frozen batch를 purge하여 full rule을 frequency-only로 축소 재생하지 않는다.
- DB/API 변경이 없으므로 migration rollback이나 data backfill은 필요 없다.
