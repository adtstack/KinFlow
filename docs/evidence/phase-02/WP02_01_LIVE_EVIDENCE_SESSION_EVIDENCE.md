# Phase 02 WP02-01 Live Evidence Session Evidence

- 검증일: 2026-07-29
- implementation commit: `dfc092521efafe67814d9a106ebb78e9af1cb6ff`
- 상태: **AUTOMATED SESSION SAFETY PASS / LIVE TWO-ADULT E2E NOT RUN**
- 범위: 실제 Android 성인 2인 검증 결과를 privacy-safe하게 초기화·기록하고 exact APK에 결속하는 operator session

## Requirement Trace

| 요구사항 | 결과 |
|---|---|
| APK package binding | PASS — `aapt dump badging`에서 읽은 실제 package가 `dev=me.newlines.kinflow.dev`, `prod=me.newlines.kinflow`와 exact match해야 init과 completion이 진행된다. |
| APK source binding | PASS — APK application metadata의 40-hex source commit, `source_state=clean`, repository commit 존재와 streaming SHA-256을 검사한다. |
| Safe initialization | PASS — direct `ci-reports/manual/*.json` 경로에만 mode `0600`으로 신규 생성하며 기존 file, symlink와 manual-root symlink를 거부한다. |
| Constrained recording | PASS — device preflight 2개와 authoritative check 27개, `pass|fail|not_run` 외 입력을 거부하고 exact schema 검증 뒤 atomic replace한다. |
| Privacy-safe output | PASS — status/result output은 environment/package, check/result count만 반환하며 path, commit, hash와 임의 subprocess error를 재출력하지 않는다. |
| Actual two-adult completion | **NOT RUN** — 두 기기 preflight 0/2, 실제 check 0/27이며 completion file을 생성하지 않았다. |

## Implemented Artifacts

- `scripts/ci/android-two-adult-e2e-evidence.mjs`
  - Android badging application ID parser와 actual APK package binding
  - clean APK inspector: package, embedded commit/state, repository commit과 SHA-256
  - 기존 all-pass completion validator에 actual package exact match 추가
- `scripts/ci/android-two-adult-e2e-session.mjs`
  - `init`: APK-derived identity로 29개 result가 모두 `not_run`인 private session 신규 생성
  - `record`: exact preflight/check target 하나와 stable result 하나만 기록
  - `status`: 식별정보·build binding을 노출하지 않는 집계만 출력
- `scripts/ci/android-two-adult-e2e-evidence.test.mjs`, `scripts/ci/android-two-adult-e2e-session.test.mjs`
  - badging, wrong-package, raw error masking, no-overwrite, path/symlink, exact allowlist, atomic replace와 redacted output 회귀 검사
- `GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md`
  - hand-edited template 절차를 `init -> record -> status -> completion validator` 절차로 교체

## Local Validation

| 검증 | 결과 |
|---|---|
| focused evidence/session tests | PASS, 16/16 |
| `npm run ci:test` | PASS, 47/47 |
| `npm run ci:workflow` | PASS, 5 jobs / 17 pinned action uses / `contents: read` |
| Flutter quality gate | PASS, 182 tests / opt-in live test 1 skip / coverage 78.52% |
| `git diff --check` | PASS |
| actual local dev APK inspector | PASS — `me.newlines.kinflow.dev`, clean commit `3df6eadc5339cd2b68509efc51cfe340333802dc`, SHA-256 `d7933ff9ee647c04552631107c98653665caf97f6443f4c359c3478fd84feec3` |
| actual remote prod APK inspector | PASS — `me.newlines.kinflow`, clean implementation commit, SHA-256 `0522e5b8e840a68c6238843c96645f2140e7a74142c5aa9c2e25744391d80caa` |

focused test의 all-pass fixture는 validator branch coverage만 제공한다. session test는 임시 repository에서 시작 상태 29개를 모두 `not_run`으로 만들며 실제 관찰 결과로 사용하지 않는다.

## Remote Validation

GitHub Actions [run `30420851520`](https://github.com/adtstack/KinFlow/actions/runs/30420851520)은 implementation commit에서 최종 PASS했다.

| job | 결과 |
|---|---|
| dependency vulnerability and license audit | PASS, 1m11s |
| Supabase DB, RLS, and contract | PASS, 2m58s |
| quality and tests | PASS, 3m41s |
| Android dev debug | PASS, 4m21s |
| Android prod debug | PASS, 4m51s |
| final CI gate | PASS, 4s |

Android report의 build binding은 다음과 같다.

| flavor | package | source | state | SHA-256 |
|---|---|---|---|---|
| dev | `me.newlines.kinflow.dev` | implementation commit | clean | `4c52c44b3888eb4ecaf2ab558840f96a606405fd6303482218be6a50c2d9ecf6` |
| prod | `me.newlines.kinflow` | implementation commit | clean | `0522e5b8e840a68c6238843c96645f2140e7a74142c5aa9c2e25744391d80caa` |

원격 prod APK artifact는 임시 directory에 내려받아 session inspector로 report의 package, commit과 SHA-256을 직접 재검증했다. dev report도 exact package, clean implementation commit과 build SHA를 기록한다.

## Manual / Deferred Validation

- 실제 Android target 두 대의 API level, signer, verified App Link와 installed package preflight는 **NOT RUN**이다.
- 실제 Google account A/B chooser, Supabase session과 distinct adult membership 관찰은 **NOT RUN**이다.
- household create, invite issue/cold dispatch/accept, restore/logout/account switch와 negative-path 27개 check는 모두 **NOT RUN**이다.
- actual `ci-reports/manual/*.json` session은 만들지 않았고 result를 자동 또는 추정으로 `pass` 처리하지 않았다.

## Data / API / Security / Privacy

- DB migration, RLS, RPC, Edge/API, Flutter runtime와 remote provider mutation은 없다.
- operator가 제공하는 값은 environment, A/B API level, exact target과 stable result뿐이다. account email, token, invite URL, ADB serial과 household/member UUID를 저장할 field가 없다.
- session file은 Git ignored 경로에만 위치하고 new/replace file permission은 `0600`이다.
- APK/tool/file failure 원문은 stable error로 치환하며 command summary에 commit, SHA와 path를 포함하지 않는다.
- 테스트용 session은 OS temporary directory에서만 생성되고 test cleanup으로 제거됐다.

## Remaining Risks / Completion Boundary

1. recorder는 입력 범위와 파일 무결성을 보장하지만 operator가 실제 화면/DB를 관찰했는지는 자동 증명하지 않는다.
2. APK artifact binding은 실행에 사용한 bytes를 고정하지만 두 실제 기기에 그 bytes가 설치됐는지는 two-device preflight와 operator 대조가 필요하다.
3. Android/OEM별 Google chooser, verified App Link, cold lifecycle과 remote Supabase 동작은 실제 두 기기에서 남아 있다.
4. WP02-01과 Phase 02 Exit Gate는 두 preflight와 27개 result가 모두 직접 관찰된 `pass`이고 final validator가 actual APK와 함께 통과하기 전까지 미완료다.

## Rollback

- implementation commit `dfc0925`를 revert하면 package binding, session CLI/test, runbook과 workplan 변경이 함께 제거된다.
- DB/API/provider mutation이 없어 migration 또는 remote rollback은 없다.

## Next Entry Condition

1. 서로 다른 online Android target 2대와 성인 Google test account 2개 준비
2. current clean dev APK build와 two-device preflight PASS
3. runbook의 `session.mjs init`으로 actual APK/API-bound ignored session 신규 생성
4. 27개 check를 직접 관찰한 직후 exact target/result만 `record`
5. `status`에서 preflight 2개와 check 27개의 all-pass를 확인한 뒤 actual APK로 completion validator PASS

위 조건 전에는 session tooling 완료를 실제 two-adult E2E 완료로 간주하지 않는다.
