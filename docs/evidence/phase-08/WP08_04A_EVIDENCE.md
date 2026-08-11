# Phase 08 WP08-04A Server-authoritative Runtime Policy Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED / PARTIAL (2026-08-09)** — WP08-04 전체와 G8 완료는 아님
- 범위: `FR-PLAT-004`, `FR-PLAT-005`, `NFR-COMP-01`, `D-030`, `D-031`, `D-042`, `CAP-018`, `T-REL-02`
- 구현 수직 조각: private versioned policy → sanitized public read → installed Android build/contract correlation → initial/retry/resume refresh → app-wide localized restriction UX → client advisory mutation stop → direct/Edge-forwarded DB-authoritative denial
- real account, hosted project, production policy, Store console, signed binary와 physical device 사용: **없음**

## 수용 기준

| 기준 | 결과 |
|---|---|
| server-authoritative global switch | PASS — dev/prod Android policy의 `mutations_enabled`를 DB trigger가 30개 non-privacy product table mutation에 적용 |
| minimum build/contract | PASS — build 하한과 optional contract 범위를 update-required가 read-only보다 먼저 평가하고 stable `KFR01`로 차단 |
| exact public policy | PASS — anon/authenticated exact content-free 10-field projection만 허용하고 private policy/audit 직접 접근 거부 |
| operator safety | PASS — service-only expected-version, correlation replay/mismatch, immutable content-free audit와 audited rollback 적용 |
| direct/Edge enforcement | PASS — direct authenticated 요청과 Edge runtime-owned marker를 가진 service RPC user operation 모두 같은 trigger를 통과 |
| privileged marker 경계 | PASS — client는 exact 5개 compatibility header만 전달할 수 있고 marker는 제거 후 Edge runtime이 소유해 추가 |
| legacy compatibility | PASS — header 없는 구버전은 prod/android/build 0/unknown contract로 해석되며 compatibility-open seed에서는 계속 동작 |
| preserved operations | PASS — 읽기·bounded offline cache·session·personal/household export·account/household deletion·legal/support/diagnostics는 전역 mutation switch 대상에서 제외 |
| strict installed identity | PASS — package ID, configured version/build, ISO contract, environment/platform 불일치 또는 provider 오류는 policy fetch 전에 fail closed |
| client restriction UX | PASS — initial/retry/foreground refresh, last-good snapshot 보존, bounded banner, fixed Play URL과 EN/KO/EN-XA 200% layout |
| advisory mutation stop | PASS — chore/calendar/household/notification/profile/billing representative notifier가 provider/network/store/ID 생성 전에 중단 |
| authority separation | PASS — compatibility header는 authorization이 아니며 RLS, role, expected version, idempotency와 domain invariant를 변경하지 않음 |

## Server·Edge 구현

- `supabase/migrations/20260808180000_app_runtime_policy.sql`
  - `app_private.app_runtime_policies`, compatibility-open dev/prod Android seed
  - immutable `app_private.app_runtime_policy_events`
  - anon/authenticated `public.get_app_runtime_policy`
  - service-only `public.configure_app_runtime_policy`
  - request compatibility parser, transaction-local successful evaluation cache와 30개 non-privacy table trigger
  - privacy/export tables 제외와 marker 없는 service/worker 보존
- `supabase/migrations/20260809100000_app_runtime_policy_volatility.sql`
  - wall-clock `evaluated_at`을 사용하는 public read RPC를 forward-only로 `VOLATILE` 선언해 schema lint와 실제 의미를 일치시킴
- `supabase/functions/_shared/runtime_policy_headers.mjs`
  - exact five-header allowlist, malformed-present fail-closed sentinel, client marker 제거와 runtime-owned marker 추가
- invite/member/notification Edge contracts and runtimes
  - compatibility header를 service-role PostgREST RPC에 전달
  - `KFR01/KFR02/KFR03`을 `CLIENT_UPDATE_REQUIRED` 426, `CLIENT_MUTATIONS_DISABLED` 503, `RUNTIME_POLICY_UNAVAILABLE` 503으로 privacy-safe mapping
  - CORS에는 client header 5개만 포함하고 privileged marker는 제외

## Flutter 구현

- domain/application/data/presentation:
  - `apps/kinflow_app/lib/features/runtime_policy/`
- infrastructure/composition:
  - `apps/kinflow_app/lib/infrastructure/supabase/supabase_app_runtime_policy_data_source.dart`
  - `apps/kinflow_app/lib/infrastructure/supabase/supabase_client_initializer.dart`
  - `apps/kinflow_app/lib/infrastructure/package_info/package_info_runtime_client_build_reader.dart`
  - `apps/kinflow_app/lib/infrastructure/url_launcher/url_launcher_runtime_policy_external_link_launcher.dart`
  - `apps/kinflow_app/lib/app/providers/auth_dependencies.dart`
  - `apps/kinflow_app/lib/app/bootstrap.dart`
  - `apps/kinflow_app/lib/app/app.dart`
- mutation advisory guard:
  - chore, calendar, household, notification, profile와 billing notifier/provider entry point
  - export/delete/privacy providers는 의도적으로 gate 밖에 유지
- localization/tests:
  - `apps/kinflow_app/lib/l10n/app_en.arb`
  - `apps/kinflow_app/lib/l10n/app_ko.arb`
  - `apps/kinflow_app/lib/l10n/app_en_XA.arb`
  - `apps/kinflow_app/test/features/runtime_policy/`
  - `apps/kinflow_app/test/infrastructure/runtime_policy_infrastructure_test.dart`
  - `apps/kinflow_app/test/support/fakes/fake_runtime_policy_dependencies.dart`

## Strict client contract

- DTO는 exact 10개 key, exact type, UTC timestamp, requested environment/platform correlation과 contract range invariant를 요구한다.
- installed package metadata는 configured application ID와 `APP_VERSION`의 version/build에 정확히 일치해야 한다. mismatch와 exception은 raw detail 없이 unavailable failure다.
- Supabase REST와 Functions에는 같은 다섯 compatibility header가 global하게 설정된다. client code는 privileged Edge marker를 구성할 수 없다.
- 정책 우선순위는 update-required → read-only → allowed다. 표시용 minimum version 문자열은 build 판정 authority가 아니다.
- restriction banner는 app child를 대체하지 않으며 최대 화면 높이를 제한하고 내부 scroll/wrap action으로 320×568, 200% pseudo text에서 overflow를 방지한다.
- update action은 validated application ID로 만든 고정 Google Play HTTPS URL만 사용하며 server-provided arbitrary URL을 열지 않는다.

## 자동 검증 결과

| 영역 | 명령/검사 | 결과 |
|---|---|---|
| Clean DB reset | `npx --no-install supabase db reset --local` | PASS, 44 migrations + seed |
| Runtime policy DB | focused pgTAP | PASS, 1 file / 28 tests |
| DB full | `npx --no-install supabase test db` | PASS, 50 files / 2543 tests |
| DB schema lint | `npx --no-install supabase db lint --local --level warning` | PASS, issue 0 |
| Edge focused | runtime header + invite/member/notification contracts | PASS, 67 tests |
| Node full | `npm run ci:test` | PASS, 136 tests |
| Runtime/auth focused Flutter | domain/repository/controller/widget/infrastructure/auth | PASS, 40 tests including 6 representative mutation guards |
| Representative mutation guards | chore/calendar/notification/profile/household/billing | PASS, focused run subset 6; blocked path provider/network/store/ID call 0 |
| App shell/accessibility focused | lifecycle host, banner, compact pseudo layout and child preservation | PASS, 25 tests |
| Flutter full | `flutter test --no-pub --reporter failures-only` | PASS, 943 tests + opt-in live 1 skip |
| Analyzer | exact Flutter 3.44.7 `flutter analyze` | PASS, issue 0 |
| Format | exact Dart 3.12.2 format drift | PASS, 561 files / drift 0 |
| Codegen | `dart run tool/verify_codegen.dart` | PASS, 8 generated files / drift 0 |
| Public config | `dart run tool/validate_public_config.dart` | PASS, examples valid/allowlisted |
| Secret scan | `dart run tool/scan_secrets.dart` | PASS, high-confidence finding 0 |
| Workflow contract | `npm run ci:workflow` | PASS, 5 jobs / 17 pinned action uses / `contents:read` |
| Contract parse | fenced YAML | PASS, runtime policy + error catalog |
| Matrix parse | fenced CSV | PASS, platform 20×12 / tests 67×11 / requirements 116×18 / risks 31×15 |
| Whitespace | `git diff --check` | PASS |

첫 compact 320×568, 200% pseudo widget 검사는 기존 `MaterialBanner` action 영역 overflow를 찾았다. 이를 app child를 가리지 않는 bounded scrollable panel과 wrapped 48dp action으로 교체한 뒤 focused 25개와 full 943개를 재실행해 통과했다. 최초 DB lint는 wall-clock `evaluated_at`을 가진 read RPC의 `STABLE` 선언 1건을 찾았고, 적용 migration을 수정하지 않고 별도 forward migration으로 `VOLATILE` 선언을 맞춘 뒤 clean reset, focused 28개, lint 0, full 2543개를 통과했다.

## 보안·개인정보 검토

- policy와 audit에는 user/account/household/member/content/provider/token/free-form reason/arbitrary URL이 없다.
- public read는 identity와 무관한 exact projection이고, private table/function helper grants는 public/anon/authenticated/service role에서 제거된다.
- operator mutation은 service role, expected version과 correlation ID를 요구하며 같은 correlation의 다른 payload 재사용을 거부한다.
- immutable audit는 before/after policy와 server timestamp만 저장하며 raw header, JWT, IP, identity와 request body를 저장하지 않는다.
- Edge는 privileged marker를 client CORS allowlist에 노출하지 않고 client-supplied 값을 버린다. invalid present compatibility value는 누락으로 완화하지 않고 stable unavailable error로 fail closed한다.
- DB trigger는 runtime policy를 authorization으로 사용하지 않는다. RLS/domain 권한 검사는 독립적으로 계속 적용된다.
- global switch가 privacy rights를 가로막지 않도록 personal export, household export, account deletion과 household deletion lifecycle table을 trigger 대상에서 제외했다.
- Flutter failure/state/UI는 raw Supabase/provider exception, header 값, installed version detail을 반사하지 않는다.
- 새 dependency, permission, secret 또는 public config key는 추가하지 않았다.

## 수동·실환경 검증

다음은 **NOT RUN**이다.

- hosted dev/prod policy migration·propagation과 service-role operator 권한/감사 로그 확인
- production policy mutation, alert/dashboard, on-call runbook과 emergency enable/disable/rollback drill
- 이전 signed N-1 APK에서 header 없음·최소 build 상승·contract 범위·rollback 실제 upgrade
- Play Store listing 이동, staged rollout pause/rollback과 update handoff
- 실제 계정·두 기기·multi-device foreground/background/resume 및 offline→online 전환
- TalkBack/system font/tablet/split-screen과 저사양 physical Android device
- iOS App Store와 Web Companion policy adapter

로컬 fake, local Supabase와 widget 자동화 통과를 hosted propagation, signed artifact, Store 절차 또는 실기기 완료로 해석하지 않는다.

## 남은 위험과 OPEN 항목

- 현재 구현은 Android 전역 non-privacy mutation switch다. FR-PLAT-004의 기능별 flag, cohort targeting과 staged percentage rollout은 미구현이다.
- policy header가 없는 N-1은 build 0으로 평가되므로 minimum build를 올리는 순간 쓰기가 차단된다. production 적용 전 signed N-1 rehearsal과 사용자 공지가 필수다.
- Edge runtime-owned marker가 누락되면 service RPC는 worker로 간주되어 정책을 우회할 수 있다. 현재 네 user-operation runtime 계약은 이를 검증하지만 새 Edge mutation 추가 시 같은 shared helper와 contract test가 필요하다.
- Edge를 거치지 않는 새 public product table 또는 mutation RPC는 trigger 설치와 privacy 분류를 release checklist에서 확인해야 한다.
- policy fetch 장애에서 읽기는 유지되고 online mutation은 DB가 판단하지만, 완전 오프라인에서는 서버 denial을 받을 수 없으므로 advisory 상태를 authority로 오해해서는 안 된다.
- hosted policy propagation latency, mutation denial rate, stable error 비율과 rollback SLO/alert가 아직 없다.

## Rollback

- 운영 rollback은 새 correlation ID와 expected version으로 `mutations_enabled=true`, 더 낮은 minimum build 또는 넓은 contract range를 적용한다. audit history는 보존한다.
- Flutter rollback은 lifecycle host, banner와 advisory guards를 제거하되 server trigger를 유지하면 구버전도 요청 시점 정책을 따른다.
- Edge rollback은 compatibility forwarding을 제거하기 전에 server policy를 compatibility-open으로 되돌려 service RPC user operation의 우회 창을 만들지 않는다.
- schema 제거가 필요하면 forward migration에서 30개 trigger를 먼저 제거하고 public RPC, immutable audit, private policy 순으로 제거한다. 적용 migration은 수정하지 않는다.

## 다음 단계

- 기능 우선순위에 따라 다음 로컬 vertical slice를 계속 구현한다.
- hosted·실계정·signed binary·Store·다중기기·실기기 검증은 사용자 요청대로 마지막 통합 Gate에 유지한다.
