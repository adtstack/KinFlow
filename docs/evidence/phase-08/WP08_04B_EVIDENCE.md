# Phase 08 WP08-04B Capability Runtime Policy Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED / PARTIAL (2026-08-09)** — WP08-04 전체와 G8 완료는 아님
- 범위: `FR-PLAT-004`, `NFR-COMP-01`, `D-031`, `D-042`, `CAP-018`, `T-REL-02`
- 구현 수직 조각: exact six-feature policy → sanitized public projection → service-only versioned audit mutation → explicit table classification → direct/Edge DB denial → strict Flutter snapshot → exact feature-family advisory guard → localized partial-read-only UX
- real account, hosted project, production policy, Store console, signed binary와 physical device 사용: **없음**

## 수용 기준

| 기준 | 결과 |
|---|---|
| exact capability switches | PASS — `household`, `chores`, `calendar`, `notifications`, `profile`, `billing` 여섯 mutation switch만 허용 |
| compatibility-safe seed | PASS — dev/prod Android 12개 row를 명시적으로 enabled seed해 기존 기능을 열어 둠 |
| exact public projection | PASS — anon/authenticated에게 scope별 exact 6개, 7-field content-free row만 feature 순으로 반환하고 private direct read를 거부 |
| operator safety | PASS — service-only expected-version, correlation replay/mismatch, immutable content-free audit와 exact-feature rollback re-enable 적용 |
| explicit DB classification | PASS — 30개 product table trigger가 무인자/unknown 없이 exact feature argument를 가짐 |
| authority precedence | PASS — global update-required → global read-only → exact feature-disabled → allowed 순서이며 `KFR06`은 `CLIENT_FEATURE_DISABLED` 503 retryable로 매핑 |
| transaction isolation | PASS — global successful evaluation과 feature별 successful evaluation cache가 분리되어 한 기능의 allow가 다른 disabled 기능을 우회하지 못함 |
| preserved operations | PASS — 읽기, unrelated feature mutation, markerless service/worker, privacy/export/delete/legal/support/diagnostics를 유지 |
| strict Flutter snapshot | PASS — global policy와 exact six unique feature rows를 한 immutable snapshot으로 만들고 unknown/missing/duplicate/malformed/scope mismatch를 거부 |
| exact client guards | PASS — 38개 mutation entry point를 자신에게 해당하는 feature family guard에 연결하고 broad global guard 사용을 구조 테스트로 금지 |
| partial-read-only UX | PASS — global restriction이 없을 때만 deterministic localized disabled-feature 목록과 retry를 표시하고 app child와 unrelated capability를 유지 |
| authority separation | PASS — feature policy는 authorization이 아니며 RLS, role, domain invariant, expected version과 idempotency를 변경하지 않음 |

## Server·Edge 구현

- `supabase/migrations/20260809110000_app_runtime_feature_policy.sql`
  - private `app_runtime_feature_policies`와 immutable `app_runtime_feature_policy_events`
  - dev/prod × exact six compatibility-open seed
  - anon/authenticated `get_app_runtime_feature_policies`
  - service-only `configure_app_runtime_feature_policy`
  - global-first, exact-feature-second `enforce_app_runtime_policy`
  - 30개 table의 explicit feature trigger 재분류와 transaction-local feature cache
- Edge stable error mapping:
  - `supabase/functions/_shared/invite_contract.mjs`
  - `supabase/functions/_shared/member_lifecycle_contract.mjs`
  - `supabase/functions/_shared/notification_endpoint_contract.mjs`
  - `KFR06`을 raw SQL/provider detail 없이 `CLIENT_FEATURE_DISABLED`, HTTP 503, retryable, `errors.clientFeatureDisabled`로 반환
- authoritative contract:
  - `docs/contracts/app-runtime-feature-policy.yaml.md`
  - `docs/contracts/error-catalog.yaml.md`

## Exact table classification

| Feature | DB trigger tables | Flutter guard entry points |
|---|---:|---:|
| profile | 1 | 1 |
| household | 4 | 8 |
| chores | 8 | 13 |
| calendar | 8 | 8 |
| notifications | 3 | 5 |
| billing | 6 | 3 |
| 합계 | 30 | 38 |

privacy/export/delete lifecycle table은 이 분류에 포함하지 않았다. 새 capability를 추가할 때 server seed, client enum, table mapping, exact parser와 tests를 함께 추가하지 않으면 fail closed한다.

## Flutter 구현

- domain/snapshot:
  - `apps/kinflow_app/lib/features/runtime_policy/domain/entities/app_runtime_policy.dart`
  - exact `AppRuntimeFeature`, strict feature policy invariant, immutable map, global+feature precedence와 deterministic disabled list
- DTO/repository/infrastructure:
  - `apps/kinflow_app/lib/features/runtime_policy/data/dto/app_runtime_feature_policy_dto.dart`
  - `apps/kinflow_app/lib/features/runtime_policy/data/mappers/app_runtime_policy_mapper.dart`
  - `apps/kinflow_app/lib/features/runtime_policy/data/repositories/provider_app_runtime_policy_repository.dart`
  - `apps/kinflow_app/lib/infrastructure/supabase/supabase_app_runtime_policy_data_source.dart`
  - exact 7-key row, exact list outer shape, six unique features, strict types/UTC/scope/version/timestamp 검증
- providers/presentation:
  - `apps/kinflow_app/lib/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart`
  - `apps/kinflow_app/lib/features/runtime_policy/presentation/widgets/app_runtime_policy_lifecycle_host.dart`
  - `Provider.family<bool, AppRuntimeFeature>` exact guard와 bounded localized feature banner
- mutation guard callsites:
  - household, chores, calendar, notifications, profile와 billing provider files
  - account/household deletion, personal/household export와 privacy provider는 의도적으로 policy advisory 밖에 유지
- localization/tests:
  - `apps/kinflow_app/lib/l10n/app_en.arb`
  - `apps/kinflow_app/lib/l10n/app_ko.arb`
  - `apps/kinflow_app/lib/l10n/app_en_XA.arb`
  - `apps/kinflow_app/test/features/runtime_policy/`
  - `apps/kinflow_app/test/architecture/dependency_boundary_test.dart`
  - `apps/kinflow_app/test/infrastructure/runtime_policy_infrastructure_test.dart`

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Clean DB reset | `npx --no-install supabase db reset --local` | PASS, 45 migrations + seed |
| Capability policy DB | focused pgTAP | PASS, 1 file / 30 tests |
| Global policy regression | focused pgTAP | PASS, 1 file / 28 tests |
| DB full | `npx --no-install supabase test db` | PASS, 51 files / 2573 tests |
| DB schema lint | `supabase db lint --schema app_private,public --level warning --fail-on error` | PASS, issue 0 |
| Edge focused | runtime header + invite/member/notification contracts | PASS, 69 tests |
| Node full | `npm run ci:test` | PASS, 136 tests |
| Runtime-policy focused Flutter | domain/repository/widget/guard/infrastructure/auth | PASS, 47 tests |
| Capability mutation guards | household/chores/calendar/notifications/profile/billing + unrelated-feature allow | PASS, 7 tests |
| Architecture guard mapping | exact file→feature/count, broad guard exclusion, privacy/export exclusion | PASS, 9 tests |
| Flutter full | `flutter test --no-pub --reporter failures-only` | PASS, 952 tests + opt-in live 1 skip |
| Analyzer | exact Flutter 3.44.7 `flutter analyze --no-pub` | PASS, issue 0 |
| Format | exact Dart 3.12.2 format drift | PASS, 566 files / drift 0 |
| Localization codegen | exact Flutter `gen-l10n` | PASS |
| Generated code | `dart run tool/verify_codegen.dart` | PASS, 8 generated files / drift 0 |
| Public config | `dart run tool/validate_public_config.dart` | PASS, examples valid/allowlisted |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| Workflow contract | `npm run ci:workflow` | PASS, 5 jobs / 17 pinned action uses / `contents:read` |
| Contract parse | fenced YAML | PASS, global + capability + error catalog; exact 6 features / 30 triggers / KFR06 |
| Matrix parse | 13 fenced CSV documents | PASS, platform 20×12 / tests 67×11 / requirements 116×18 / risks 33×15 |
| Whitespace | `git diff --check` | PASS |

첫 focused Flutter run에서 WP08-04A 시절 테스트가 broad provider를 직접 override하고 있어 새 feature-family callsite를 제어하지 못하는 fixture drift 6건을 발견했다. 각 테스트를 exact capability override로 전환하고, disabled chores가 정상 calendar mutation을 막지 않는 격리 사례를 추가한 뒤 focused 47개와 full 952개를 통과했다. 제품 구현은 analyzer 단계부터 issue 0이었고 이 실패는 새 의미를 반영하지 못한 기존 test harness 경계였다.

## 보안·개인정보 검토

- public feature policy와 audit에는 user/account/household/member/content/provider/token/free-form reason/cohort/arbitrary URL이 없다.
- private policy/audit table과 helper는 public, anon, authenticated, service role에서 직접 접근할 수 없다. operator mutation RPC만 service role에 노출한다.
- public read는 identity와 무관한 exact projection이며 missing/unknown/duplicate row를 enabled로 추측하지 않는다.
- Edge는 SQLSTATE만 privacy-safe stable error로 변환하고 raw database/provider response를 앱에 반사하지 않는다.
- marker 없는 service/worker를 유지하되 Edge-forwarded user operation은 service role이어도 global·feature policy를 모두 통과한다.
- feature switch는 권한 부여가 아니다. 기존 RLS, role, domain constraints, expected-version과 idempotency는 독립적으로 계속 적용된다.
- Flutter banner와 error state는 server copy, identity, content와 raw exception을 표시하지 않는다.
- 새 dependency, permission, secret, public config key, analytics event 또는 remote copy surface는 추가하지 않았다.

## 수동·실환경 검증

다음은 **NOT RUN**이다.

- hosted dev/prod migration과 exact six policy propagation
- production policy mutation, operator authorization, audit retention, alert/dashboard와 emergency disable/re-enable drill
- cohort/percentage/per-account 또는 per-household targeting
- 이전 signed N-1 APK와 새 binary의 global/feature policy 상호 운용
- 실제 성인 계정·두 기기·foreground/background/resume·offline→online 전환
- Play staged rollout/pause/rollback, TalkBack, system font, tablet/split-screen과 physical Android device
- iOS App Store와 Web Companion adapter

로컬 service-role synthetic RPC, local Supabase와 Flutter 자동화 통과를 hosted propagation, Store 절차, 실계정 또는 실기기 완료로 해석하지 않는다.

## 남은 위험과 OPEN 항목

- WP08-04/G8은 hosted operator propagation, rollback/alert drill, signed N-1과 Store/device evidence 전까지 PARTIAL이다.
- percentage/cohort targeting은 별도 contract에서 identity/privacy, sticky assignment, exposure audit와 rollback semantics를 먼저 결정해야 한다.
- 새 table이나 mutation path가 생기면 30-table classification과 38 client guard count를 의도적으로 갱신해야 하며 architecture/pgTAP drift 실패 없이 자동 추가되지 않는다.
- production policy 값은 이번 작업에서 변경하지 않았다.

## 결론

WP08-04B의 local capability-policy 수직 조각은 구현·자동 검증을 완료했다. Android의 여섯 기존 capability를 서로 독립적으로 중단하면서 global emergency policy, 읽기, 다른 기능, privacy rights와 worker를 보존하고 DB를 최종 권위로 유지한다. 실계정·hosted·Store·다중기기·실기기 검증은 사용자의 우선순위대로 마지막 통합 Gate에 남긴다.
