# Phase 02 WP02-01 Dev Asset Links Work Plan

- 작성일: 2026-07-29
- 기준 commit: `ac3098d`
- Work Package: WP02-01 / WP02-04 — deployable dev Digital Asset Links contract
- 상태: SLICE COMPLETE (LOCAL + REMOTE PASS) / OWNED HOST DEPLOYMENT PENDING

## Requirements

| ID | 이번 vertical slice |
|---|---|
| FR-AUTH-004 / FR-FLT-006 | dev invite host의 `/.well-known/assetlinks.json`에 현재 설치 dev 앱의 exact package와 signing SHA-256 association을 준비한다. |
| WP02-04 / T-LINK-01 / T-LINK-02 | Android App Link가 요구하는 `handle_all_urls`, `android_app`, package와 certificate fingerprint 형식을 자동 검증한다. |
| Security | unknown relation/namespace/package, malformed/duplicate fingerprint와 prod-debug association을 fail-closed로 차단한다. signing private material이나 invite token은 산출물에 넣지 않는다. |

## Scope

1. Astro 정적 사이트의 향후 public asset 경로에 dev-only `/.well-known/assetlinks.json`을 둔다.
2. statement list의 exact schema, relation, namespace, package와 SHA-256 fingerprint를 검사하는 Node validator와 unit tests를 추가한다.
3. 설치 APK의 application ID와 signer fingerprint를 추출해 statement list와 비교하는 Android verification wrapper를 추가한다.
4. prod flavor는 debuggable APK로 association을 만들 수 없도록 wrapper에서 거부한다.
5. APK build audit가 App Link intent filter의 `DEFAULT` category도 고정하도록 보강한다.
6. public site README/runbook에 HTTPS 200, `application/json`, no redirect와 dev/prod signing 경계를 기록한다.

## Explicit Non-scope Until External Inputs Exist

- owned domain 선택, DNS와 hosting 배포
- Google Cloud/Supabase console 설정
- production Play App Signing fingerprint 또는 prod `assetlinks.json`
- OS `verified` 판정과 성인 2계정·2기기 E2E 완료 주장
- 공개 지원/개인정보/계정 삭제 Astro 페이지 구현

## Data / API Impact

- DB migration, RLS, RPC, Edge/API와 Flutter runtime 변경 없음.
- certificate fingerprint는 공개 association 식별자다. keystore/private key/password는 읽어서 복사하거나 Git에 넣지 않는다.

## Validation

- `npm run ci:test`
- valid dev statement, malformed schema/relation/package/fingerprint, duplicate/extra association tests
- current dev APK package/signer versus checked-in dev statement
- prod debug APK rejection
- default dev/prod APK audit regression
- full Flutter quality and repository secret scan
- remote GitHub Actions required jobs and final gate

## Stop / Rollback

- APK signer와 statement fingerprint가 다르면 배포를 중단한다.
- prod signing fingerprint가 Play-delivered certificate로 확인되지 않으면 prod file을 만들지 않는다.
- owned host가 HTTPS 200, JSON content type와 no-redirect 계약을 충족하지 않으면 OS 검증을 실행하지 않는다.
- 이 slice commit을 revert하면 정적 association, validator/wrapper와 강화된 APK category audit만 제거된다. DB/API rollback은 없다.

## Completion Boundary

- 이 slice는 현재 dev APK에 정확한 배포 입력을 준비하는 것까지 완료한다.
- 실제 owned host 배포와 Android OS `verified` 결과 전에는 App Link manual gate 또는 Phase 02 Exit Gate를 완료로 선언하지 않는다.
