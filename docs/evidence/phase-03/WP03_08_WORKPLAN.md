# Phase 03 WP03-08 Static Chore Templates Work Plan

## Status

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-08)** — WP03/G3와 실환경 Gate 완료는 아님
- 수직 조각: chore 생성 → PII-free 정적 template 선택 → 편집 가능한 title/repeat 초깃값 → 기존 one-time/repeating create 계약
- 요구사항: `FR-CHORE-010`, `FR-CHORE-001`, `FR-CHORE-002`, `NFR-PRIV-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- 실제 계정·remote Supabase·실기기 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.
- 완료 증거: `docs/evidence/phase-03/WP03_08_EVIDENCE.md`

## Product boundary

- 사용자는 집안일 생성 화면에서 앱에 포함된 일반적인 집안일 여섯 개 중 하나를 빠른 시작으로 선택할 수 있다.
- template 선택은 localized title과 추천 반복 주기만 폼에 복사한다. 담당자, 날짜, 시간, 설명은 추측하거나 변경하지 않는다.
- 적용된 값은 일반 폼 값과 같아서 저장 전 자유롭게 수정할 수 있다. title 또는 repeat를 직접 바꾸면 선택 표시는 해제되지만 입력 값은 보존한다.
- template를 선택하지 않고 기존처럼 빈 폼에서 직접 입력하는 흐름을 유지한다.
- marketplace, household별 template, 서버 seed, 동기화, 추천/개인화, 사용 analytics는 이번 slice에 없다.

## Exact catalog and data contract

catalog version은 `2026-08-08-wp03-08`이며 다음 exact entry만 허용한다.

| stable key | suggested cadence | localized title source |
|---|---|---|
| `dishes` | `daily` | ARB `choreTemplateDishes` |
| `kitchen_reset` | `daily` | ARB `choreTemplateKitchenReset` |
| `laundry` | `weekly` | ARB `choreTemplateLaundry` |
| `vacuuming` | `weekly` | ARB `choreTemplateVacuuming` |
| `bathroom_cleaning` | `weekly` | ARB `choreTemplateBathroomCleaning` |
| `trash_and_recycling` | `weekly` | ARB `choreTemplateTrashAndRecycling` |

- stable key는 lowercase ASCII snake case이고 exact lookup만 지원한다. 공백 제거, 대소문자 변환 또는 unknown fallback은 하지 않는다.
- domain catalog에는 사용자 표시 문자열, 사람/가구 식별자, 설명, 장소, 날짜, 시간이 없다.
- 추천 cadence는 `daily` 또는 `weekly`뿐이며 기존 `ChoreRecurrenceFrequency` API로 변환하기 전 UI draft selection으로만 사용한다.
- 선택 시 localized title이 사용자 편집 가능한 content가 되고 기존 160자/control-character 검증을 그대로 거친다.

## Database, API, and persistence

- DB migration, seed, RPC, Edge function, RLS, local storage와 network 요청을 추가하지 않는다.
- `CreateOneTimeChoreRequest`와 `CreateRecurringChoreRequest` shape를 변경하지 않는다.
- template stable key, catalog version, 선택 상태와 analytics event는 request, repository, cache, log에 전달하거나 저장하지 않는다.
- 저장 시에는 사용자가 확인·수정한 title, 기존 description, assignee, due date/time과 recurrence만 기존 경로로 보낸다.
- 향후 server-seeded catalog는 별도 versioned exact DTO, authorization, cache/fallback, localization과 privacy 검토 없이는 이 local catalog를 대체할 수 없다.

## Privacy and security

- catalog에는 이름, 이메일, member/household/user ID, 위치, 일정, 메모, 실제 household content 또는 token이 없다.
- remote image/URL, markdown/HTML, executable content와 free-form server text를 사용하지 않는다.
- template 선택은 권한을 확장하지 않는다. 기존 active household·active adult roster와 create RPC 검증이 그대로 authoritative하다.
- template stable key나 localized label을 새 analytics/log event로 기록하지 않는다.
- unknown key는 fail closed하고 catalog 밖의 값으로 draft를 만들지 않는다.

## UI, accessibility, and localization

- 생성 안내 뒤, title field 앞에 빠른 시작 heading/body와 wrapping `ChoiceChip` 여섯 개를 표시한다.
- chip은 선택 상태를 semantics로 노출하고 Material padded tap target을 사용한다. section과 form은 compact 화면과 200% text에서 scroll 가능해야 한다.
- template 적용으로 repeat가 바뀌면 기존 recurrence summary live region이 결과를 알린다.
- 모든 사용자 표시 문자열은 EN/KO/EN-XA ARB에 있고 pseudo 문자열은 영어보다 최소 30% 길다.
- chip의 stable widget key는 `chore.template.<stable-key>`다. title/repeat/submit 등 기존 key와 직접 입력 흐름을 유지한다.

## Automated evidence plan

1. domain catalog exact order/count/version, unique safe stable key, exact lookup와 unknown rejection
2. domain source에 Flutter/Riverpod/provider SDK와 localized/free-form content가 없는 architecture regression
3. widget에서 모든 template 노출, daily/weekly title·repeat 적용과 선택 semantics
4. 적용 후 title/repeat 직접 편집 시 선택 표시 해제 및 편집 값 그대로 기존 request 저장
5. 담당자/date/time/description 미변경과 template metadata가 request shape에 추가되지 않음
6. 직접 입력 one-time/repeating 생성 회귀와 stale failure reset
7. KO localized title과 EN-XA 320×568 200% scroll/overflow 0, chip 48dp target
8. focused/full Flutter, localization exact coverage, formatter, analyzer, codegen, config/secret/contract/matrix/whitespace Gate

## Stop conditions and rollback

- template가 identity/household content를 포함하거나 서버로 stable key를 전송하면 배포하지 않는다.
- 선택이 assignee/date/time/description을 암묵적으로 바꾸거나 사용자의 편집을 덮어쓰면 배포하지 않는다.
- 직접 입력 또는 one-time/repeating 생성 회귀, localization 누락, 200% overflow, 48dp 미만 action이 있으면 배포하지 않는다.
- rollback은 template section, domain catalog, ARB와 해당 tests/docs만 제거한다. DB/API/persisted data rollback은 없다.

## Completion boundary

이 slice가 green이어도 server-managed/household-specific templates, onboarding의 세 개 template guided setup, 추천 개인화와 실제 계정·실기기 UX 검증은 완료가 아니다. `FR-CHORE-010`의 앱 내 정적 template 경계만 local automated complete로 평가한다.
