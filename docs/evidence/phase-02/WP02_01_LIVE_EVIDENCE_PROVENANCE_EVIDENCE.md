# Phase 02 WP02-01 Live Evidence APK Provenance Evidence

- 검증일: 2026-07-29
- implementation commit: `3df6eadc5339cd2b68509efc51cfe340333802dc`
- 상태: **LOCAL + REMOTE AUTOMATED PASS / LIVE TWO-ADULT E2E NOT RUN**
- 범위: two-adult completion JSON의 commit을 실제 APK source provenance와 fail-closed로 연결

## Requirement Trace

| 요구사항 | 결과 |
|---|---|
| APK source identity | PASS — application metadata에 exact 40-hex source commit과 `clean`/`dirty` state를 포함한다. |
| Build wrapper | PASS — repository Android build/run wrapper가 current `HEAD`와 build 시작 시 worktree state를 계산해 Gradle manifest placeholder로 전달한다. |
| Completion gate | PASS — evidence commit 존재와 APK SHA-256 외에 APK embedded commit exact match 및 `clean` state를 모두 요구한다. |
| Fail-closed parsing | PASS — application direct-child metadata만 허용하고 missing, malformed, duplicate, mismatch, dirty와 aapt failure를 stable error로 거부한다. |
| Security / Privacy | PASS — metadata와 report에는 Git commit/state만 있으며 account, device serial, token, email, invite 또는 household/member identifier가 없다. |

## Implemented Artifacts

- `apps/kinflow_app/android/app/build.gradle.kts`
  - lowercase 40-hex commit과 `clean|dirty` state validation
  - direct Gradle build default는 zero commit / dirty로 fail-closed
- `apps/kinflow_app/android/app/src/main/AndroidManifest.xml`
  - `me.newlines.kinflow.SOURCE_COMMIT`
  - `me.newlines.kinflow.SOURCE_STATE`
- `scripts/ci/android-build.sh`, `scripts/run-android.sh`
  - current HEAD/worktree state 계산과 Android project argument 전달
  - build gate의 binary manifest presence audit와 report 기록
- `scripts/ci/android-two-adult-e2e-evidence.mjs`
  - bounded `aapt dump xmltree` reader
  - application direct-child provenance parser
  - evidence/APK source commit exact match와 clean-only completion gate
- `scripts/ci/android-two-adult-e2e-evidence.test.mjs`
  - real-shaped manifest parse, duplicate/malformed 위치 거부
  - mismatch/dirty/tool failure masking과 existing commit/hash/check 회귀
- `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md`
  - clean build prerequisite, build report 확인과 embedded commit 사용 절차

## Local Validation

| 검증 | 결과 |
|---|---|
| focused evidence contract | PASS, 10/10 |
| actual dev/prod dirty APK build | PASS — both reports and binary manifests exposed `source_state=dirty` |
| clean actual-config dev APK build | PASS — embedded implementation commit / `clean` exact match |
| clean dev APK | PASS, 216,124,115 bytes / SHA-256 `d7933ff9ee647c04552631107c98653665caf97f6443f4c359c3478fd84feec3` |
| repository self-test | PASS, 41/41 |
| workflow/action contract | PASS, 5 jobs / 17 pinned action uses / `contents: read` |
| Flutter full suite | PASS, 182 passed / 1 opt-in live skipped |
| Flutter analyze / format | PASS, issue 0 / 158 files final change 0 |
| codegen / public config / secret | PASS, generated drift 0 / allowlist PASS / high-confidence secret 0 |
| coverage | PASS, 2,445/3,115 lines (78.49%) |
| `git diff --check` | PASS |

Toolchain은 Flutter 3.44.7, Dart 3.12.2, Android build-tools/aapt 36.0.0을 사용했다. Local actual public config의 값은 출력·evidence에 복사하지 않았다.

## Remote Validation

GitHub Actions [run `30419331951`](https://github.com/adtstack/KinFlow/actions/runs/30419331951)은 clean checkout의 implementation commit에서 최종 PASS했다.

| job | 결과 |
|---|---|
| dependency vulnerability and license audit | PASS, 1m16s |
| Supabase DB, RLS, and contract | PASS, 3m21s |
| quality and tests | PASS, 3m45s |
| Android dev debug | PASS, 8m33s |
| Android prod debug | PASS, 9m33s |
| final CI gate | PASS, 4s |

두 Android job은 clean checkout의 current HEAD를 metadata에 넣고 build gate에서 manifest value와 report를 검증한 뒤 APK를 artifact로 업로드했다. 업로드된 report artifact를 다시 내려받아 다음 값을 직접 확인했다.

| remote artifact | embedded/report provenance | SHA-256 |
|---|---|---|
| dev debug | `3df6eadc5339cd2b68509efc51cfe340333802dc` / `clean` | `2db7c5ec10d3f72b19796365ce03cd51b6b045c43cd6075e5765d366863ab5bd` |
| prod debug | `3df6eadc5339cd2b68509efc51cfe340333802dc` / `clean` | `43f52d8874ae14e79a22d090685ab4ce656552d3c0a374b98c7c90e8c66f8bb7` |

## Data / API / Security / Privacy

- DB migration, RLS, RPC, Edge/API, Supabase/Google provider와 runtime auth flow 변경 없음.
- manifest metadata의 commit은 repository source identity이며 credential이나 사용자 identifier가 아니다.
- `aapt`, commit verifier와 file reader failure 원문은 completion CLI에서 재출력하지 않는다.
- actual config value, OAuth client, publishable key와 APK 내부 config는 evidence에 기록하지 않았다. APK digest만 기록했다.
- dirty development build는 계속 가능하지만 completion evidence로는 fail-closed다.

## Manual / Deferred Validation

- actual Android device A/B에 clean APK 설치: **NOT RUN**
- installed bytes와 local/CI APK artifact 동일성: **NOT RUN**
- Google A/B login, Supabase sessions와 invitation flow: **NOT RUN**
- exact 27 live checks와 completion JSON: **0/27, NOT RUN**

## Remaining Risks / Completion Boundary

1. embedded provenance는 APK가 선언한 commit/state를 source wrapper와 연결하지만 외부 signed attestation 또는 reproducible-build proof는 아니다.
2. 실제 기기에 설치된 APK bytes는 device-side digest를 수집하지 않으므로 operator가 동일 파일을 두 기기에 설치해야 한다.
3. manual result의 진위는 자동 증명하지 못하며 two-adult runbook의 직접 관찰이 필요하다.
4. 실제 preflight와 27개 check가 모두 pass인 privacy-safe completion JSON 전에는 WP02-01 live gate가 미완료다.

## Rollback

- implementation commit `3df6ead`을 revert하면 Gradle/manifest wrapper, validator/tests와 runbook provenance 변경이 함께 제거된다.
- DB/API/provider mutation이 없어 remote rollback은 없다.

## Next Entry Condition

1. implementation commit에서 만든 clean actual-config dev APK를 Android device A/B에 설치
2. two-device preflight PASS
3. evidence JSON commit에 APK embedded `3df6eadc5339cd2b68509efc51cfe340333802dc`를 기록
4. actual 27 checks를 직접 관찰하고 stable result만 기록
5. completion validator가 commit existence, APK digest, embedded clean commit과 all-pass checks를 함께 검증

위 live 관찰 전에는 provenance PASS를 two-adult E2E PASS로 사용하지 않는다.
