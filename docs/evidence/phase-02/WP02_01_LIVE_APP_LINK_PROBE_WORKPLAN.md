# Phase 02 WP02-01 Live App Link Probe Work Plan

- 작성일: 2026-07-29
- 기준 commit: `3082c04`
- Work Package: WP02-01 / WP02-04 — deployed Digital Asset Links HTTP contract probe
- 상태: LOCAL PASS / REMOTE CI PENDING

## Requirements

| ID | 이번 vertical slice |
|---|---|
| FR-AUTH-004 / FR-FLT-006 | owned host 배포 뒤 Android가 읽는 exact well-known URL을 HTTPS로 직접 검사한다. |
| WP02-04 / T-LINK-01 / T-LINK-02 | status 200, no redirect, JSON content type, bounded valid body와 exact package/fingerprint statement를 자동 검증한다. |
| Security | scheme/port/path/wildcard/localhost/IP host, oversized body와 unexpected association을 fail-closed로 거부하고 response body/token을 log에 출력하지 않는다. |

## Scope

1. 기존 Android public config host 검증을 재사용 가능한 함수로 분리한다.
2. `https://<host>/.well-known/assetlinks.json`만 요청하는 Node live verifier를 추가한다.
3. redirect manual, 10-second timeout, 64 KiB body cap, exact `application/json` media type와 existing Asset Links validator를 연결한다.
4. fetch를 주입하는 unit tests로 success, redirect/status/content-type, oversized/malformed body, host와 statement mismatch를 검증한다.
5. APK-to-local-file wrapper의 optional host argument가 local signer 비교 후 live probe를 연속 실행하게 한다.
6. runbook에 배포 전 local gate와 배포 후 live gate 명령을 분리한다.

## Explicit Non-scope Until External Inputs Exist

- DNS/hosting 배포 또는 도메인 소유권 설정
- 실제 Google Digital Asset Links API/Android OS `verified` 결과
- Google Cloud/Supabase provider 설정과 계정 로그인
- 성인 2인·Android 2기기 E2E

## Data / API Impact

- DB, RLS, RPC, Edge/API, Flutter runtime와 dependency 변경 없음.
- probe는 공개 well-known JSON만 GET하며 credential, cookie 또는 invite URL을 전송하지 않는다.

## Validation

- live verifier unit tests and full `npm run ci:test`
- current APK → local static statement regression
- unsafe host, redirect, non-200, wrong content type, oversized/malformed/mismatched statement rejection
- full Flutter quality/secret scan, dev/prod APK regression, remote CI

## Stop / Rollback

- redirect나 content-type ambiguity가 있으면 성공으로 완화하지 않는다.
- body가 64 KiB를 넘거나 statement가 exact local signer와 다르면 배포 검증을 실패시킨다.
- slice commit revert로 live probe와 wrapper optional host 연결만 제거된다. DB/API rollback은 없다.

## Completion Boundary

- 이 slice는 실제 host가 생겼을 때 자동 검증할 probe 준비까지만 완료한다.
- real host에서 probe를 실행하고 Android가 `verified`를 보고하기 전에는 App Link manual gate를 완료로 선언하지 않는다.

## Local Evidence

- repository Node tests: PASS, 22/22; live probe success/failure cases 4개 포함
- shell syntax: PASS
- current dev APK → checked-in statement: PASS
- prod debuggable APK → production association: EXPECTED FAIL
- Flutter quality: PASS; format drift 0, analyzer issue 0, 176 tests + 1 opt-in skip, coverage 2,393/3,091 (77.42%)
- public config / secret scan / generated code: PASS; high-confidence secret 0, generated drift 0
- dev Android build: PASS; 216,120,695 bytes, SHA-256 `50348407a63b1c535f350ccec4082919b6a3788ecb8a3024d75d98f1e0cfcc4d`
- prod debug Android build: PASS; 216,120,615 bytes, SHA-256 `6a54dbd776e2906a6efe99f0fdc2f197b0ef08ca44c894556fd35ecfb6be55b0`
- owned HTTPS host live probe / Android OS verification: NOT RUN — external host is not selected or deployed
