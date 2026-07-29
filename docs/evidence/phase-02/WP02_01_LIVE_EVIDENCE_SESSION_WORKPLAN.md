# Phase 02 WP02-01 Live Evidence Session Work Plan

- 작성일: 2026-07-29
- 기준 commit: `12e961b`
- Work Package: WP02-01 — privacy-safe two-adult live evidence session
- 상태: **COMPLETE — SESSION TOOLING / LIVE GATE PENDING**

## Problem

현재 runbook은 tracked template를 복사한 뒤 APK commit/hash, timestamp, API level과 27개 result를 사람이 JSON에서 직접 편집한다. exact validator가 잘못된 최종 파일은 거부하지만 편집 중 stale APK hash, wrong package, key typo, free-form note 또는 식별정보를 임시로 넣을 위험은 남는다. 또한 completion validator는 evidence의 application ID를 검증하지만 제공된 APK package를 직접 대조하지 않는다.

## Requirements

1. session `init`은 clean APK에서 package, embedded source commit과 SHA-256을 직접 읽고 environment/package를 exact match한다.
2. operator 입력은 `dev|prod`, Device A/B API level, exact result target과 `pass|fail|not_run`으로 제한한다.
3. session file은 Git ignored `ci-reports/manual/` 아래에만 새로 만들고 기존 파일을 덮어쓰지 않는다.
4. `record`는 device preflight 2개와 authoritative 27개 check만 수정하고 canonical UTC timestamp를 갱신한다.
5. 매 변경은 exact incomplete schema validation 뒤 atomic replace하며 symlink/non-regular file을 거부한다.
6. `status`와 command output은 pass/fail/not-run count, environment/package와 check count만 제공하고 path, commit, hash 또는 임의 문자열을 재출력하지 않는다.
7. session 도구는 실제 관찰을 추정하거나 자동으로 pass 처리하지 않는다. 초기 상태는 preflight/check 29개 모두 `not_run`이다.

## Scope

- APK badging application ID parser와 completion-time package binding
- reusable clean APK inspector
- `init`, `record`, `status` session CLI
- ignored-path, no-overwrite, exact-key/result, atomic update와 redacted summary tests
- runbook의 manual JSON editing 절차를 session CLI 절차로 교체

## Explicit Non-scope

- ADB 연결, APK 설치, Google account/session 또는 invitation 조작
- 화면/DB 관찰 없이 result를 pass로 변경
- email, token, device serial, invite URL, household/member UUID 또는 free-form note 수집
- actual completion JSON 생성 또는 tracked evidence에 사용자 결과 저장
- signing attestation, reproducible build 또는 WP02-05~07 구현

## Validation

- badging parser, wrong-package와 aapt failure masking tests
- init exact schema/metadata/no-overwrite/path boundary tests
- record allowlist/result/atomic/symlink/status tests
- existing completion/provenance/27-key regression
- repository self-test, Flutter quality, dev/prod Android build와 GitHub Actions final gate
- secret scan, `git diff --check`

## Stop / Rollback

- wrong-package APK가 session/completion에 수용되거나 init이 기존 파일을 덮으면 중단한다.
- unknown key/free-form value/symlink가 기록되거나 output에 commit/hash/path/raw tool error가 나타나면 중단한다.
- rollback은 inspector/recorder/test/runbook/workplan 변경을 함께 revert한다. DB/API/provider mutation은 없다.

## Completion Boundary

- session 도구는 수동 증거 입력을 안전하게 만들 뿐 실제 result의 진위를 증명하지 않는다.
- 두 기기 preflight와 27개 check를 직접 관찰해 모두 pass로 기록하고 final validator가 actual APK와 함께 통과하기 전에는 4단계 live gate가 pending이다.

## Implementation Result

- implementation commit: `dfc092521efafe67814d9a106ebb78e9af1cb6ff`
- package badging binding, reusable clean APK inspector와 `init|record|status` session CLI를 구현했다.
- focused test 16/16, repository self-test 47/47, Flutter 182 tests와 coverage 78.52%, workflow contract, secret scan과 diff check가 통과했다.
- actual local dev APK와 GitHub Actions의 actual prod APK artifact가 새 inspector를 통과했다.
- GitHub Actions run `30420851520`에서 dependency, backend, quality, dev/prod Android와 final gate가 모두 통과했다.
- actual session/completion JSON은 생성하지 않았고 two-device preflight 0/2, live check 0/27 상태를 유지했다.
