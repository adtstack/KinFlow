# Phase 03 WP03-08 Static Chore Templates Evidence

## 결과

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-08)** — WP03/G3/출시 완료는 아님
- 범위: `FR-CHORE-010`, `FR-CHORE-001`, `FR-CHORE-002`, `NFR-PRIV-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- 구현 수직 조각: chore 생성 화면 → PII-free 앱 내 catalog → localized title·추천 repeat 적용 → 사용자 편집 → 기존 one-time/repeating create request
- DB migration, server seed, RPC/Edge, local persistence, network, analytics 추가: 없음
- 실제 계정·remote Supabase·실기기 사용: 없음

## 수용 기준

| 기준 | 결과 |
|---|---|
| 앱 내 정적 template | PASS — versioned exact 6-entry domain catalog를 앱에 포함 |
| 개인정보 없음 | PASS — stable generic key와 daily/weekly cadence 외 identity/content metadata 없음 |
| 선택적 빠른 시작 | PASS — 초기 선택 없음, 기존 직접 입력 흐름 유지 |
| 편집 가능한 적용 | PASS — localized title과 repeat만 채우고 모든 폼 값을 저장 전 수정 가능 |
| 기존 값 보존 | PASS — description, assignee, due date/time은 template 선택으로 변경되지 않음 |
| persistence/API 비확장 | PASS — template key/version/selection을 request, repository, cache, log, analytics로 보내지 않음 |
| one-time/repeating 회귀 | PASS — template 미선택 직접 입력과 template 적용 후 기존 create 계약 모두 통과 |
| 접근성·국제화 | PASS — EN/KO/EN-XA exact coverage, pseudo 30% expansion, wrapping ChoiceChip, 48dp, 320×568 200% overflow 0 |

## Exact catalog

catalog version은 `2026-08-08-wp03-08`이다.

| stable key | 추천 반복 | EN title | KO title |
|---|---|---|---|
| `dishes` | daily | Dishes | 설거지 |
| `kitchen_reset` | daily | Kitchen reset | 주방 정리 |
| `laundry` | weekly | Laundry | 세탁 |
| `vacuuming` | weekly | Vacuuming | 청소기 돌리기 |
| `bathroom_cleaning` | weekly | Bathroom cleaning | 욕실 청소 |
| `trash_and_recycling` | weekly | Trash and recycling | 쓰레기와 재활용품 버리기 |

- domain은 stable key와 cadence enum만 가진다. 사용자 표시 문자열은 ARB에서 presentation이 exhaustively 매핑한다.
- exact parser는 공백, 대문자, unknown/custom key를 정규화하지 않고 거부한다.
- compile-time const list는 runtime mutation을 거부하고 key uniqueness·lowercase snake case를 test로 고정했다.
- localized title은 사용자가 명시적으로 template를 누른 뒤에만 일반 chore draft content가 되며 기존 trim, 160자, control-character 검증을 거친다.

## 사용자 흐름과 동작

1. 생성 안내와 title 사이에 빠른 시작 section과 여섯 `ChoiceChip`을 표시한다.
2. 선택하면 title cursor를 적용 문자열 끝에 두고 daily/weekly repeat field와 recurrence summary를 갱신한다.
3. stale one-time/repeating creation failure와 retry identity는 template 선택 시 reset한다.
4. title 또는 repeat를 직접 바꾸면 template 선택 표시만 해제하고 현재 draft 값은 보존한다.
5. 담당자, 설명, due date와 due time은 선택 전 값을 유지한다.
6. 제출은 선택 여부를 보지 않고 기존 `CreateOneTimeChoreRequest` 또는 `CreateRecurringChoreRequest`만 만든다.

긴 pseudo text에서 기존 assignee/repeat dropdown의 selected row가 가로 overflow하는 문제도 이번 검증에서 발견해 `isExpanded`와 한 줄 ellipsis를 적용했다. underlying `Text`의 전체 문자열은 semantics에 유지되고 form 전체는 계속 scroll 가능하다.

## 구현 파일

- domain/UI:
  - `apps/kinflow_app/lib/features/chores/domain/entities/chore_template.dart`
  - `apps/kinflow_app/lib/features/chores/presentation/screens/one_time_chore_creation_screen.dart`
- localization/generated:
  - `apps/kinflow_app/lib/l10n/app_en.arb`
  - `apps/kinflow_app/lib/l10n/app_ko.arb`
  - `apps/kinflow_app/lib/l10n/app_en_XA.arb`
  - `apps/kinflow_app/lib/l10n/app_localizations.dart`
  - `apps/kinflow_app/lib/l10n/app_localizations_en.dart`
  - `apps/kinflow_app/lib/l10n/app_localizations_ko.dart`
- tests/contracts/docs:
  - `apps/kinflow_app/test/features/chores/chore_domain_test.dart`
  - `apps/kinflow_app/test/features/chores/one_time_chore_widget_test.dart`
  - `apps/kinflow_app/test/localization/localization_contract_test.dart`
  - `apps/kinflow_app/test/architecture/dependency_boundary_test.dart`
  - `docs/contracts/chore-templates.yaml.md`
  - `docs/evidence/phase-03/WP03_08_WORKPLAN.md`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Focused Flutter | chore domain/widget + localization + architecture | PASS, 63 tests |
| Flutter full | `flutter test --no-pub --reporter failures-only` | PASS, 814 tests + opt-in live 1 skip |
| Analyzer | `flutter analyze --no-pub --fatal-infos --fatal-warnings` | PASS, issue 0 |
| Format | `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 513 files / drift 0 |
| Codegen | `dart run tool/verify_codegen.dart` | PASS, 8 generated files / drift 0 |
| Public config | `dart run tool/validate_public_config.dart` | PASS, examples valid/allowlisted |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| Contract parse | fenced `chore-templates.yaml` exact version/entry/persistence assertions | PASS, 6 exact entries |
| Matrix parse | fenced CSV matrix 13개 declared-row/column 검사 | PASS, requirements 116×18 / tests 65×11 |
| Whitespace | `git diff --check` | PASS |

초기 focused 실행은 새 section으로 폼이 길어져 기존 widget test 두 곳이 화면 밖 control을 직접 tap해 실패했다. 실제 scroll 조작으로 test를 수정했다. 새 200% test는 기존 assignee/repeat dropdown의 pseudo text overflow를 발견했고 expanded/ellipsis 보완 후 재실행해 통과했다. 한국어와 pseudo 앱을 한 test에서 연속 교체했을 때 Riverpod dispose timer가 남은 문제는 locale별 독립 test로 분리해 lifecycle을 명확히 했다. 최종 focused 63개와 full 814개는 모두 green이다.

## 보안·개인정보 검토

- catalog entry는 generic stable key와 cadence뿐이며 user/account/household/member ID, 이름, 이메일, 위치, 일정, 설명, 실제 가구 content가 없다.
- remote URL/image, HTML/markdown, executable payload, auth token, provider object와 arbitrary map을 읽지 않는다.
- template 선택은 기존 active household와 active adult roster authorization을 우회하거나 확장하지 않는다.
- template ID, catalog version과 selected state는 request/data layer에 들어가지 않는다. 저장되는 title은 사용자가 선택 후 확인·수정할 수 있는 일반 chore content뿐이다.
- 새 log/analytics event를 만들지 않았고 template label/selection을 관찰 가능 metadata로 기록하지 않는다.
- DB/API/RLS/local cache/public config/native permission/dependency 변경이 없다.
- architecture scan은 새 domain file이 Flutter, Riverpod, Supabase 또는 provider SDK를 import하지 않음을 전체 feature tree에서 확인한다.

## 수동·실환경 검증

다음은 **NOT RUN / NOT IMPLEMENTED**다.

- 실제 성인 계정과 remote Supabase에서 template 적용 chore를 생성하고 다른 기기에서 확인
- Android 물리 기기의 keyboard, TalkBack, system font 200%, landscape/tablet UI
- 서버 관리 또는 household별 template seed, remote catalog version/cache/fallback
- onboarding 중 template 또는 직접 입력으로 집안일 세 개를 만드는 guided flow
- 사용 빈도 analytics, 추천/개인화, marketplace와 template 편집/공유

로컬 fake repository와 widget automation을 실제 사용자·네트워크·기기 완료로 해석하지 않는다. 실계정 검증은 사용자 지시에 따라 기능 개발이 충분히 끝난 마지막 Gate에 둔다.

## 남은 위험과 완료 경계

1. 여섯 generic title과 추천 cadence가 모든 가구 문화·주기에 맞는지는 사용자 연구로 검증하지 않았다. 추천은 편집 가능하지만 initial catalog 품질은 운영 feedback이 필요하다.
2. localized title이 실제 chore title로 저장되므로 locale를 바꿔도 이미 만든 chore title은 자동 번역되지 않는다. 이는 user content를 임의로 변경하지 않는 의도된 경계다.
3. server catalog를 나중에 추가할 때 free-form content나 identity targeting을 현재 exact local 경계로 몰래 혼합하면 privacy·localization·offline semantics가 깨진다. 별도 versioned DTO와 threat review가 필요하다.
4. onboarding의 세 개 chore 생성 단계와 연결하지 않았으므로 PRD의 guided activation 경험은 아직 별도 기능이다.
5. 실제 screen reader와 physical-device keyboard/touch evidence가 없으므로 G3/G7 또는 출시 Gate를 완료로 표시하지 않는다.

`FR-CHORE-010`의 **앱 내 정적·PII-free template variant**는 local automated complete다. 요구사항 전체와 traceability는 server/onboarding/real-device 가능성을 명시하기 위해 `IN_PROGRESS`를 유지한다.

## Rollback

- 생성 화면의 template section/mapping/state, `chore_template.dart`, 신규 ARB와 해당 tests/docs를 함께 제거한다.
- 기존 title/description/assignee/repeat/date/time form과 one-time/repeating controller/request는 변경 없이 유지할 수 있다.
- dropdown large-text 보완은 template와 독립적인 접근성 수정이므로 rollback에서도 유지할 수 있다.
- DB/API/remote/local persisted data와 dependency migration이 없어 data rollback 또는 cleanup은 없다.

## 다음 기능 후보

- 실계정 Gate를 계속 미룬 채 다음 local 사용자 기능은 `FR-CAL-008` 비차단 overlap hint 또는 onboarding의 template 3개 guided setup을 별도 vertical slice로 비교한다.
- 우선순위 결정 시 기존 create/read 계약을 재사용하고 서버 schema 확장 없이 테스트 가능한 slice를 먼저 선택한다.
