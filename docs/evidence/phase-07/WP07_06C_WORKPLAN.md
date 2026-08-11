# Phase 07 WP07-06C Cross-Feature Timezone Picker Adoption Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-09)** — WP07-06 전체와 G7 완료는 아님
- 수직 조각: 남은 Store MVP 시간대 자유 입력 전수 확인 → 공용 read-only selection field → 첫 가구 생성 선택·submit → 알림 preference 선택·save/cancel → 기존 server validation

## Requirements and completion boundary

- `FR-HH-002`: 첫 가구 생성의 기본 시간대를 자유 입력이 아닌 IANA 지역·도시 선택으로 확정한다.
- `FR-NOTIF-004`: recipient quiet-hours 시간대를 같은 picker로 선택하고 기존 DST/server-local 평가 계약을 유지한다.
- `FR-SET-002`: WP07-06B profile/household 선택 UX와 동일한 catalog·failure·접근성 동작을 사용한다.
- 완료 시 Store MVP Flutter presentation의 사용자 편집 가능한 timezone free-text field는 0개이고, 첫 가구·개인 profile·기존 가구·알림의 네 필드가 같은 공용 selection component를 사용한다.

## Architecture and UX

- 기존 picker를 settings 전용 widget에서 app 공용 presentation widget으로 이동하고 read-only form field와 modal launcher를 함께 제공한다.
- field activation은 현재 draft를 selected value로 넘기며 row를 선택한 경우에만 controller를 바꾼다. 닫기·back·catalog failure는 draft를 바꾸지 않는다.
- catalog loading/retry/empty/current/offset/DST/selected semantics와 최대 100건 검색은 WP07-06B 계약을 그대로 사용한다.
- 첫 가구는 기존 `Asia/Seoul` 초기값을 유지하고 선택 전후 form validation과 idempotent create flow를 유지한다.
- 알림 dialog는 authoritative preference timezone에서 시작하고 선택 후 save할 때만 update를 호출하며 cancel은 timezone을 포함한 모든 draft를 버린다.
- EN/KO/EN-XA copy를 입력 표현에서 선택 표현으로 바꾸고 compact 200% full-scroll 동작을 유지한다.

## Server, security, and privacy boundary

- migration, RPC, grant, RLS, Edge Function, remote DTO와 payload shape는 변경하지 않는다.
- 첫 가구 submit은 기존 atomic `create_first_household`, 알림 save는 기존 optimistic-version `update_notification_preference`가 PostgreSQL IANA catalog로 다시 검증한다.
- picker catalog를 authorization 또는 persistence authority로 사용하지 않는다.
- 검색어·선택 이력·offset/DST를 저장·전송·로그·분석하지 않는다.

## Automated evidence plan

- household widget: London 검색·선택 후 exact create request, default Seoul 회귀, cancel/no mutation, compact pseudo scroll.
- notification widget: New York 검색·선택 후 exact preference update, dialog cancel no update, read-only field, 기존 quiet interval/version 유지.
- shared widget/profile: loading/failure/retry/current/selected/200% 회귀.
- static adoption: presentation source에서 timezone controller를 사용하는 editable field가 남지 않았는지 검사.
- focused suites 후 architecture/localization/settings/household/notification, analyzer, format, full Flutter, root contract, matrix/YAML, secret, whitespace gate를 실행한다.

## Manual and deferred evidence

- hosted PostgreSQL/bundle parity, 실제 계정 onboarding·notification 저장, cross-device refresh, process restart, physical keyboard/TalkBack, DST·여행 실기기는 사용자 지시대로 마지막 통합 Gate에서 검증한다.

## Rollback

- 공용 selection field를 current-value display로 되돌려도 기존 create/update command와 저장값은 유지된다.
- UI rollback은 server contract, audit, quiet-hours delivery 또는 recurrence row를 변경하지 않는다.
