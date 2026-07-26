# Phase 01 WP01-07 Evidence

- Work Package: WP01-07 CI
- 기준 commit: base `32de58c`; WP01-07 change
- 검증일: 2026-07-25
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2, Node 24.15.0, Java 21.0.9, Supabase CLI 2.109.1, Docker 28.3.2
- 결과: **REPOSITORY/LOCAL AUTOMATION PASS / REMOTE GITHUB CI·ANDROID DEVICE PENDING**
- 범위 제한: production provider, signing/Play upload, branch protection, iOS/Web와 Google 로그인은 포함하지 않음

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP01-07 quality gate | PASS | format, fatal analyzer, 59 unit/widget/architecture tests, coverage, config/secret/codegen, workflow self-test |
| D-007 / NFR-017 | PASS | l10n/build_runner 재생성 후 5 generated file byte drift 0 |
| D-029 / SPEC-010 | REPOSITORY PASS | GitHub Actions 5-job workflow와 동일 repository-local script; remote run은 push 전이라 PENDING |
| D-032 / D-037 | PASS | dev/prod package 분리와 merged APK min/target/compile API 24/36/36 |
| D-033 / NFR-SEC-02 | PASS | workflow 권한 `contents: read`, secret context 0, public example config만 build, credential persistence off |
| D-038 / ADR-0002 | PASS | Android-only matrix; deferred iOS/macOS job 0 |
| D-042 / NFR-COMP-01 | PASS | fresh local reset, migration manifest/hash, schema lint 0 |
| NFR-018 / T-STATIC-01~04 | PASS | format 0 diff, analyzer issue 0, secret 0, reviewed license allowlist, offline vulnerability finding 0 |
| T-ARCH-01 | PASS | dependency boundary와 observability SDK boundary tests 포함 |
| T-BUILD-01 | PASS | dev/prod debug APK build, metadata/permission/checksum audit |
| T-DB-01 | PASS | local DB reset과 migration/seed 재적용 |
| T-DB-02 | FOUNDATION PASS | 현재 foundation RLS allow/deny pgTAP 37/37; Phase 02 full authorization matrix는 non-scope |
| T-CONTRACT-01 | FOUNDATION PASS | Edge health positive/negative contract와 Flutter live adapter 1/1 |

## Implementation

- `pull_request`, `main` push, `workflow_dispatch`에서 `quality`, `dependency_audit`, `backend`, dev/prod `android` matrix를 실행하고 `CI gate`가 outcome을 집계한다.
- 모든 source job은 Ubuntu 24.04, timeout과 concurrency cancellation을 사용한다. workflow 전체 권한은 `contents: read`뿐이고 checkout credential을 보존하지 않는다.
- Flutter 3.44.7과 Node 24.15.0을 exact pin하고 Java 21, lockfile enforcement, npm clean install을 사용한다. npm install은 `--ignore-scripts --no-audit --no-fund`로 untrusted PR install script와 bulk audit metadata 전송을 막는다.
- quality script는 로컬과 CI에서 같은 format/analyze/test/coverage/config/secret/codegen/actionlint command를 실행한다. explicit lock resolution 뒤 analyze/test/build에는 `--no-pub`을 사용한다.
- backend script는 local stack을 시작한 경우에만 종료하고, reset/lint/pgTAP/Edge/Flutter contract 상태와 migration SHA-256만 report에 남긴다. local key와 `.temp`는 upload하지 않는다.
- Android script는 flavor 입력을 exact allowlist하고 merged APK package, label, API와 permission set을 검증한다. 실패 report와 success-only APK upload를 분리해 감사 실패 산출물은 배포 artifact가 되지 않는다.
- report/APK artifact는 commit SHA가 포함된 고유 이름과 14일 retention을 사용한다.

## CI Supply-chain / Privacy Contract

| 도구/action | 고정값 |
|---|---|
| `actions/checkout` | v6.0.2 / `de0fac2e4500dabe0009e67214ff5f5447ce83dd` |
| `actions/setup-node` | v6.4.0 / `48b55a011bda9f5d6aeb4c2d9c7362e8dae4041e` |
| `actions/setup-java` | v5.2.0 / `be666c2fcd27ec809703dec50e508c2fdc7f6654` |
| `actions/upload-artifact` | v7.0.1 / `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| `subosito/flutter-action` | v2.23.0 / `1a449444c387b1966244ae4d4f8c696479add0b2` |
| actionlint | v1.7.12; Linux archive `8aca8d…a3d8`, binary `c872d6…4cd4`; Darwin archive `aba9ce…953f`, binary `8db117…3888` |
| OSV-Scanner | v2.3.8; Linux binary `bc98e1…92dc`, Darwin binary `a8cd65…4216` |

- private personal repository에는 GitHub Code Security entitlement가 없어 Dependency Review Action을 required job으로 사용하지 않았다. repository setting은 변경하지 않았다.
- OSV-Scanner는 공개 npm/Pub fixture만 보면서 database 2개를 임시 격리 cache에 받는다. 실제 `package-lock.json`/`pubspec.lock`은 별도 `--offline --offline-vulnerabilities --data-source native --no-resolve` 실행에서 읽어 외부로 package metadata를 보내지 않는다.
- npm lock 15개와 hosted Pub 130개의 license를 실제 resolved package/lock metadata에서 검사했다. 허용 SPDX는 Apache-2.0, BSD-2-Clause, BSD-3-Clause, MIT, MPL-2.0이며 unknown/강한 copyleft marker는 fail-closed 한다.
- OSV offline scan은 npm 15개와 Pub 135개(SDK-related lock entry 포함), 총 150 exact version을 검사했고 known vulnerability finding은 0이었다.

## Automated Validation

| 명령 | 결과 |
|---|---|
| `npm run ci:test` | PASS, Node self-test 9/9 |
| `npm run ci:workflow` | PASS, 5 jobs / pinned action uses 17 / `contents:read` / offline supply-chain contract |
| actionlint v1.7.12 | PASS, workflow syntax/expression/runner validation finding 0 |
| `bash -n` CI/local scripts + `node --check` CI modules | PASS |
| dependency license audit | PASS, hosted Pub 130 + npm 15 |
| OSV-Scanner offline vulnerability audit | PASS, exact versions 150, finding 0 |
| `dart format --output=none --set-exit-if-changed lib test tool` | PASS, 66 files, changed 0 |
| `flutter analyze --fatal-infos --fatal-warnings` | PASS, issue 0 |
| `flutter test --coverage` | PASS, 59 passed + local connectivity opt-in 1 skipped; 769/862 lines, 89.21% |
| public config / secret / codegen validators | PASS, config allowlist, high-confidence secret 0, generated drift 0 |
| backend gate | PASS, reset, schema lint 0, pgTAP 37/37, Edge contract, Flutter live adapter 1/1 |
| dev/prod Android build/audit | PASS, 두 package/API/permission/checksum contract 일치 |

상세 command와 핵심 output은 `logs/wp01-07-ci.log`에 있다. default Flutter suite의 connectivity 1건은 의도적으로 opt-in이며 backend job에서 실제 local URL/publishable key를 process argument로만 전달해 별도 1/1 PASS로 닫았다.

## Android Artifacts

debug APK는 `.gitignore` 대상이고 repository에 저장하지 않는다. 아래 workspace build는 CI script 자체 검증 결과이며 signing/Play artifact가 아니다.

| Flavor | package | API | bytes | SHA-256 |
|---|---|---|---:|---|
| dev | `me.newlines.kinflow.dev` | min 24 / target 36 / compile 36 | 184,883,497 | `7404dd0dc2ab71b2cb215bd3dcd974dfeb08be4363ab1d3e88e1a4206a12fb1f` |
| prod | `me.newlines.kinflow` | min 24 / target 36 / compile 36 | 184,883,416 | `607b2bad6b8018e9e337188a640bd14afa46fe23e7419045b27c721af8b8c1d8` |

두 APK의 permission은 `INTERNET`과 package-scoped `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`만 존재한다. clean staged export의 Java 21 build도 dev 165,445,357 bytes(`fc0a43…ebde`), prod 165,444,764 bytes(`020558…844a`)로 같은 metadata/permission contract를 통과했다. debug APK byte equality는 보장하지 않고 각 run checksum을 artifact report에 기록한다.

## Clean Staged-index Reproduction

- staged implementation index만 `/private/tmp/kinflow-wp01-07-final.jgifiN`에 export했고 repository `.git`, 기존 `.dart_tool`, build output과 `node_modules`를 포함하지 않았다.
- offline enforced pub get, Node self-test 9/9, workflow contract/actionlint, format 66 files, analyzer issue 0, full Flutter test 59 + opt-in 1 skip, coverage 769/862(89.21%), config/secret/codegen을 통과했다.
- resolved Pub/npm license audit와 public-fixture DB download 후 network-disabled OSV exact-version scan을 통과했다.
- Java 21.0.9에서 clean dev/prod APK build와 package/API/permission/checksum audit를 통과했다.
- 이 clean pass 뒤 자동 package resolution을 더 줄이는 `--no-pub` 2곳만 추가했다. bash/Node/workflow contract와 Flutter option parsing을 재검증했으며 application/generated/lockfile 내용은 바뀌지 않았다.

## Contract Integrity

| File | SHA-256 |
|---|---|
| `.github/workflows/ci.yml` | `26fbcc20d4289e64d9553d0302338650432621c3d00dd294946dc12c51c77711` |
| `scripts/ci/flutter-quality.sh` | `fd5ef4f6881625dd794f68ba6de8c6d4de394c8c8002fcce765edca6dcfad091` |
| `scripts/ci/supabase-backend.sh` | `d503bf5d84cb3e3f4367493013bc7c021feb376875279518bc3fdcfdc66ab26c` |
| `scripts/ci/android-build.sh` | `34e5d49585ccc7999c147a1d37844ae3604ada261f45f2635a5c8bcdd84cb47d` |
| `scripts/ci/osv-offline-scan.sh` | `fb04a99c8e6c6754b4a91af1dc4880e621eaad64f00e95d8839c3f0c660e9536` |
| `scripts/ci/workflow-contract.mjs` | `f4fdfd81c7073395b9680c23645c82300333e901c536e8d53f0bf2b415edb64c` |
| `apps/kinflow_app/pubspec.lock` | `1d733753db145eb8e08e9697df31e6e8dc5ac7f4a3b768766f54024af33f3950` |
| `package-lock.json` | `2d5dbdcffd50114818251e6f766ba2a160e61aefe0e31062d60a94be96c4ac42` |

## Data / API / Dependency Review

- DB migration, seed, RLS, Edge/API/domain contract 변경은 없다. migration 1개 `20260724000000_foundation.sql`의 SHA-256은 `650cc415a72f87584ffb262d303dfe28341dc6770ef1efe870218281fbea79a0`이다.
- Flutter/npm runtime dependency와 lockfile 변경은 없다. CI execution tool/action만 추가했으며 version/SHA/checksum으로 고정했다.
- build artifact는 debug APK와 공개 metadata report뿐이다. service role, local key, environment dump, signing material, provider credential은 report/artifact path에 포함하지 않는다.

## Manual / Remote Validation

- `adb devices -l`: 연결 device/emulator 0대. Android 실제 boot와 dev/prod visual separation은 **NOT RUN**이다.
- GitHub workflow는 아직 push하지 않아 run URL, GitHub-hosted Ubuntu/Java 21 result와 artifact download는 **NOT RUN**이다.
- branch protection/ruleset required check 설정은 repository 외부 변경이므로 **NOT CHANGED**다.
- signed AAB, Play internal/closed upload와 production approval은 **NOT RUN / non-scope**다.

## Security / Privacy

- untrusted PR에서 production secret/environment 접근이 없고 `pull_request_target`, write permission, mutable action ref, `continue-on-error` bypass를 self-test가 거부한다.
- dependency inventory는 공개 OSV API나 deps.dev로 보내지 않는다. DB 다운로드와 private lockfile scan을 process/network mode로 분리한다.
- npm lifecycle script를 실행하지 않고 npm audit bulk payload도 보내지 않는다. dependency source가 바뀌면 license/OSV/lock parser가 다시 gate한다.
- backend report는 migration hash와 pass/fail/tool version만 포함한다. Supabase status의 local publishable key는 Flutter child process argument에만 사용하고 출력·파일·artifact로 저장하지 않는다.

## Remaining Risks / OPEN Decisions

- remote GitHub-hosted run과 `CI gate` branch protection 적용 전에는 Phase 01의 “CI green” Exit Gate를 닫지 않는다.
- Android device가 없어 실제 shell boot/large text/dark/dev-prod visual smoke는 pending이다.
- OSV database는 실행 시점 최신 public snapshot이라 checksum을 고정하지 않는다. scanner binary와 actual offline mode는 고정·검증하며 DB freshness는 run artifact 시점에 귀속한다.
- `sentry_flutter` legacy Kotlin Gradle Plugin warning은 build blocker가 아니지만 Flutter upgrade 전에 plugin migration을 재검토한다.
- debug APK는 unsigned development evidence이며 release signing/provenance/Play delivery를 대체하지 않는다.

## Rollback

- 이 change를 되돌리면 `32de58c`의 WP01-06 상태로 복귀한다.
- `.github/workflows/ci.yml`, `scripts/ci`, package scripts, derived report ignore, README와 WP01-07 문서를 함께 제거한다.
- DB/API/data/provider/remote setting 변경이 없어 migration 또는 data rollback은 없다. push 후 생성된 artifact는 14일 retention 만료 또는 별도 승인된 삭제로 처리한다.

## Next Entry

- 이 commit을 push해 GitHub-hosted `CI gate`와 artifact를 확인하고 `CI gate`를 branch protection/ruleset required check로 지정한다.
- 연결 Android에서 dev/prod shell 수동 smoke를 수행하면 Phase 01 Exit/Handoff를 닫을 수 있다.
- 그 다음 Phase 02는 Google provider 연결을 당장 미루는 사용자 결정에 따라 provider console 없이 구현 가능한 auth/session/route/RLS 계약부터 시작한다.
