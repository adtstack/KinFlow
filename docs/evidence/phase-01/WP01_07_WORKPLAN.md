# Phase 01 WP01-07 Work Plan

- 작성일: 2026-07-25
- 기준 commit: `32de58c`
- Work Package: WP01-07 CI
- 상태: COMPLETE (repository/local + GitHub-hosted automation); branch protection와 Android device는 PENDING

## Requirements

| ID | 구현 범위 |
|---|---|
| WP01-07 | format/analyze/test/codegen, DB/RLS/contract, Android dev/prod build, artifact/test report를 GitHub Actions gate로 연결 |
| D-007 / NFR-017 | committed generated code를 재생성하고 byte drift 0을 모든 PR에서 강제 |
| D-029 / SPEC-010 | GitHub Actions 기반 CI와 재현 가능한 repository-local command를 사용 |
| D-032 / D-037 | dev/prod application ID를 분리하고 Android min/target/compile API 24/36/36을 artifact에서 검증 |
| D-033 / NFR-SEC-02 | untrusted PR에 production secret을 전달하지 않고 공개 example config만 Android build에 사용 |
| D-038 / ADR-0002 | Android 단일 출시 결정에 따라 iOS/macOS CI는 이번 gate에서 제외 |
| D-042 / NFR-COMP-01 | clean local reset과 DB lint/test로 forward-only migration baseline을 검증 |
| NFR-018 / T-STATIC-01~04 | format diff 0, analyzer info/warning 0, codegen drift 0, secret/dependency/license gate |
| T-ARCH-01 | full Flutter test suite의 dependency boundary 검사를 PR gate에 포함 |
| T-BUILD-01 | dev/prod debug APK build, identity/API/permission/checksum 검증과 artifact 보존 |
| T-DB-01 / T-DB-02 | Supabase local start/reset과 현재 foundation RLS allow/deny pgTAP matrix 통과 |
| T-CONTRACT-01 | Edge Function health positive/negative contract와 Flutter live adapter connectivity 통과 |

## CI Trust / Reproducibility Contract

- trigger는 `pull_request`, `main` push, 수동 `workflow_dispatch`로 제한한다. `pull_request_target`은 사용하지 않는다.
- workflow 기본 권한은 `contents: read`만 부여하고 checkout credential persistence를 끈다.
- PR job은 repository/environment secret을 참조하지 않는다. Android build는 versioned public example config만 사용한다.
- GitHub와 third-party action은 검토한 release의 full commit SHA로 고정하고 version comment를 함께 남긴다.
- Flutter SDK는 3.44.7 exact, `pubspec.lock`은 `flutter pub get --enforce-lockfile`, npm dependency는 `npm ci`로 고정한다.
- Java/Node/Flutter/Dart/Supabase/Gradle version과 build checksum을 report에 남긴다.
- job timeout, concurrency cancellation, 최소 artifact retention을 명시해 개인 운영 비용과 hung job을 제한한다.
- coverage/test report와 backend summary에는 공개 metadata만 남긴다. Supabase `.temp`, local key, token, environment dump는 upload하지 않는다.

## Planned Jobs

1. `quality`: exact Flutter bootstrap, lockfile enforcement, format, fatal analyze, full unit/widget/architecture tests와 coverage, config/secret/codegen validator, CI policy self-test
2. `dependency_audit`: npm/Pub lockfile 전 항목의 license allowlist와 exact-version OSV vulnerability offline scan
3. `backend`: project-scoped Supabase CLI install, local stack start, reset, lint, pgTAP/RLS, Edge health contract, Flutter live adapter test, always cleanup
4. `android`: dev/prod matrix build, merged APK package/API/permission audit, SHA-256 report, flavor별 immutable artifact upload
5. `gate`: 필수 job outcome을 하나의 branch-protection check로 집계하고 job summary 생성

## Repository-local Commands / Tests

1. CI workflow contract validator 자체 positive/negative unit tests
2. workflow trigger/permission/action-SHA/secret-free/required-job/artifact-retention static validation
3. coverage LCOV parser positive/invalid-input unit tests와 machine-readable summary 생성
4. Flutter quality command 전체(format/analyze/test/coverage/config/secret/codegen)
5. clean Supabase start/reset/lint/pgTAP/Edge/Flutter connectivity와 cleanup
6. dev/prod APK clean build, package/API/permission/checksum audit
7. npm/Pub lock parser와 license classifier self-test, 공개 fixture로 OSV database를 받은 뒤 network-disabled actual lock scan
8. workflow YAML parse, shell syntax, JSON/package lock consistency
9. staged-index clean reproduction에서 quality와 CI contract gate 재실행

## Data / API / Dependency Impact

- DB migration, seed, RLS policy, Edge/API/domain contract 변경 없음. 현재 WP01-04 baseline을 fresh local stack에서 실행한다.
- Flutter/npm runtime dependency 추가 없음. GitHub Actions execution dependency만 full SHA로 고정한다.
- private personal repository에는 GitHub Code Security entitlement가 없어 Dependency Review Action을 필수 gate로 사용할 수 없다. OSV-Scanner와 database는 version/checksum을 검증해 받되 실제 lockfile scan은 `--offline`과 native/no-resolve mode에서 수행하여 dependency metadata를 외부로 전송하지 않는다.
- debug APK와 redacted report만 GitHub artifact에 보존한다. signing key, provider credential, production rollout은 포함하지 않는다.

## Manual / Remote Validation

- repository-local workflow는 로컬에서 같은 script로 검증한다.
- 실제 GitHub Actions run URL은 commit push 전에는 확인할 수 없어 최초 계획에서 `NOT RUN`으로 분리했으며, 완료 결과는 아래 Remote Completion Update에 기록한다.
- Android 실제 기기 shell smoke는 연결 device가 있을 때만 실행하며 device가 없으면 Phase 01 Exit Gate의 pending 항목으로 유지한다.

## Non-scope

- Google 로그인/provider console, production Supabase/Sentry 연결
- signed AAB, Fastlane, Play Console internal/closed upload, production approval/rollout
- iOS/macOS/Web build와 staging environment
- remote GitHub branch protection/ruleset 변경과 repository secret 생성
- Phase 02 full household/auth RLS authorization matrix

## Rollback

- workflow, repository-local CI scripts/tests, package scripts, README와 WP01-07 evidence를 함께 되돌리면 `32de58c`의 WP01-06 상태로 복귀한다.
- DB/API/data/provider 설정 변경이 없어 migration 또는 remote rollback은 없다. GitHub에서 이미 workflow가 실행된 경우 보존 artifact는 retention 만료 또는 별도 승인된 삭제로 처리한다.

## Remote Completion Update

- 최초 push run [30225981503](https://github.com/adtstack/KinFlow/actions/runs/30225981503)은 Ubuntu runner의 ShellCheck `SC2129`가 gate summary의 반복 redirect를 지적해 Quality와 최종 gate만 실패했다. dependency, backend, dev/prod Android job은 통과했다.
- `cdd7a42`에서 summary 출력을 단일 redirect block으로 묶고 local self-test 9/9, workflow contract와 actionlint를 재검증했다.
- 재실행 [30332633213](https://github.com/adtstack/KinFlow/actions/runs/30332633213)은 Quality, dependency, backend, dev/prod Android와 최종 `CI gate`가 모두 통과했다. report 5개와 debug APK 2개가 14일 정책으로 생성됐다.
- `adb devices -l`은 연결 기기 0대를 반환했다. 실제 Android shell과 dev/prod visual smoke는 여전히 pending이다.
- branch protection 조회는 현재 PAT의 repository administration read 권한이 없어 HTTP 403이었다. 이 작업에서 ruleset을 변경하지 않았으며 required-check enforcement는 별도 확인 대상이다.
