# Phase 03 WP03-10 First-Household Guided Chore Setup Work Plan

## Status

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-09)** — WP03/G3/출시 완료는 아님
- 수직 조각: 첫 가구 생성 성공 → active household 전환 → 집안일 template 3개 선택·검토 → 기존 recurring-create RPC 3회 → Today
- 요구사항: `FR-HH-001`, `FR-CHORE-002`, `FR-CHORE-005`, `FR-CHORE-010`, `NFR-REL-01`, `NFR-PRIV-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-048`, `D-051`
- 실제 계정, remote Supabase, 두 기기 Realtime과 실제 Android/iOS 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.
- 완료 증거: `docs/evidence/phase-03/WP03_10_EVIDENCE.md`

## Product boundary

- 첫 가구 생성 직후 사용자는 앱 내 PII-free catalog에서 정확히 세 개의 서로 다른 집안일을 선택한다.
- 각 선택은 localized title과 추천 daily/weekly 반복을 채우며, 저장 전 title과 반복을 수정할 수 있다.
- 빠른 설정 항목은 현재 로그인한 active adult에게 배정되고 household의 server-authoritative 오늘 날짜부터 all-day 반복된다. 이 기본값을 화면에서 명확히 설명한다.
- 세 항목을 모두 만들면 Today로 이동한다. 사용자는 확인 dialog를 거쳐 설정을 건너뛰거나 부분 성공 후 Today로 계속할 수 있다.
- 일반 집안일 생성 화면과 직접 입력 경로는 유지한다. household별/server template, 추천 개인화, template analytics, invite 자동 실행과 onboarding 완료 flag 저장은 이번 slice에 없다.

## Domain and application contract

- guided batch는 정확히 세 entry, 서로 다른 exact `ChoreTemplatePreset`, 유효한 1~160자 title과 daily/weekly recurrence만 허용한다.
- entry 순서는 immutable catalog 순서로 정규화해 요청·진행 표시·재시도를 결정적으로 만든다.
- setup loader는 active household의 `loadToday` 결과에서 exact household ID, household timezone과 local date를 얻는다. persistent cache 결과는 mutation 기준으로 사용하지 않고 `offlineReadOnly`로 닫는다.
- 각 entry는 기존 `RecurringChoreDraft` validation과 `CreateRecurringChoreRequest`를 사용한다. description과 due time은 `null`이며 template key/version은 request에 없다.
- controller는 항목별로 서로 다른 command ID를 한 번 생성한다. 동일 frozen batch 재시도는 같은 ID를 유지하고 이미 성공한 항목을 다시 호출하지 않는다.
- 제출은 중복 호출을 coalesce하고 catalog 순서로 순차 실행한다. 세 RPC는 하나의 DB transaction이 아니므로 failure state는 exact completed count를 보존한다.
- 일부 성공 후 selection/title/repeat는 현재 route 동안 잠겨 request ambiguity를 안전하게 재시도한다. 사용자가 이탈하면 이미 생성된 항목은 보존된다.

## Database, API, persistence, and routing impact

- DB migration, RPC, Edge function, RLS policy, dependency와 native permission을 추가하지 않는다.
- 기존 `loadToday`와 `createRecurringChore` repository/API shape를 바꾸지 않는다.
- `/onboarding/chores` protected route를 추가한다. active household만 접근할 수 있고 no-household/unauthenticated state는 기존 guard로 각각 household onboarding/sign-in으로 이동한다.
- household 생성 성공 후 local active-household snapshot write까지 끝난 경우에만 guided route로 이동한다. snapshot write failure는 기존 fail-closed auth lock을 유지한다.
- selection, progress, command IDs와 draft는 process memory에만 있고 별도 local cache/analytics/log에 저장하지 않는다.

## Privacy and security

- catalog stable key/version과 선택 행동은 network, DB, cache, analytics 또는 log에 보내지 않는다.
- 저장되는 content는 사용자가 화면에서 확인·수정한 일반 chore title뿐이다. 이름, 이메일, household/member ID를 새 telemetry에 추가하지 않는다.
- assignee와 household는 auth lifecycle의 active snapshot에서 가져오지만 server RPC의 active membership, household scope, entitlement와 recurrence 검증이 계속 authoritative하다.
- cache-only Today state, household mismatch, malformed input과 provider exception은 fail closed하고 raw error를 표시하지 않는다.

## UI, accessibility, and localization

- progress live region은 선택 수 또는 생성 완료 수를 `0/3`부터 `3/3`까지 알린다.
- exact six template는 wrapping filter chips로 표시하고 세 개 선택 후 나머지는 비활성화한다. 선택된 세 항목에는 title field와 daily/weekly control을 제공한다.
- 제출 중과 failure ambiguity 이후 draft control을 잠근다. retry는 남은 항목만 처리하며 부분 성공 count를 사용자에게 명확히 표시한다.
- skip/partial-exit은 destructive data removal이 아니지만 activation 중단을 확인하는 dialog를 거친다.
- EN/KO/EN-XA ARB만 사용하고 compact 320×568, 200% text, scroll, 48dp action target과 screen-reader semantics를 자동 검증한다.

## Automated evidence plan

1. domain exact-three/unique/catalog-order/title/cadence invariant와 immutable entry list
2. controller server-date load, household mismatch/cache-only/error fail closed
3. three sequential recurring requests, current-member assignment, all-day start date와 template metadata 부재
4. duplicate submit coalescing, unique command IDs, partial failure count, same-key retry와 successful-entry non-resend
5. route guard: active household 허용, no household/unauthenticated 거부, first-household handoff
6. widget: 0/3 selection, max three, editable title/repeat, submit, retry, skip confirm와 Today refresh
7. KO localization, EN-XA compact 200% scroll/overflow 0와 action target
8. full Flutter tests, analyzer warning 0, formatter/codegen/config/secret/contract/matrix/whitespace gates

## Stop conditions and rollback

- template metadata가 request/telemetry/persistence에 포함되거나 cache-only date로 mutation하면 배포하지 않는다.
- 세 entry가 같은 command ID를 공유하거나 retry가 성공한 entry를 재생성하거나 ambiguous failure 뒤 draft를 바꿀 수 있으면 배포하지 않는다.
- household/current member를 client 값만으로 승인하거나 route guard가 no-household/unauthenticated 접근을 허용하면 배포하지 않는다.
- rollback은 household 성공 handoff를 Today로 되돌리고 guided route/screen/controller/domain/ARB/tests/docs를 제거한다. 기존 recurring chores와 API/DB data는 정상 사용자 데이터이므로 삭제하지 않는다.

## Completion boundary

이 slice가 green이어도 process-death 후 부분 setup 자동 재개, activation 완료 marker/analytics, server/household-specific template, invite 결합, 실제 두 성인·remote·두 기기·실기기 경험은 완료가 아니다. 첫 가구 직후 세 개 template chore를 안전하게 만들 수 있는 local automated flow만 완료로 평가한다.
