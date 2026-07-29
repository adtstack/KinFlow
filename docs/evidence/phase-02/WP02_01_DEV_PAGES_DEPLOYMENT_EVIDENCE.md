# Phase 02 WP02-01 Dev Pages Deployment Evidence

- Work Package: WP02-01 / WP02-04 — owned dev App Link host deployment
- 기준 commit: app repository base `4ef94e7`; Pages repository deployment `47b57e1`
- 검증일: 2026-07-29
- 환경: macOS arm64, Flutter 3.44.7, Android API 36 `sdk_gphone64_arm64`
- 결과: **DEV PAGES + LIVE CONTRACT + ANDROID VERIFIED PASS / GOOGLE PROVIDER·TWO-ADULT E2E PENDING**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-AUTH-004 / FR-FLT-006 | PASS | owned root HTTPS host가 current dev package와 signer의 exact Digital Asset Links statement를 제공한다. |
| WP02-04 / T-LINK-01 / T-LINK-02 | PASS | live endpoint, Google statement API, Android OS domain verification과 cold-start intent가 모두 일치한다. |
| Security / Privacy | PASS | 공개 package/fingerprint와 no-index 정적 안내만 배포했고 사용자 데이터, analytics, credential과 secret은 배포하지 않았다. |

## External State

- public repository: `adtstack/adtstack.github.io`
- deployment commit: `47b57e1694a671c6a7525274e89a695b15b4b376`
- Pages source: `main` branch `/`
- Pages URL: `https://adtstack.github.io/`
- association URL: `https://adtstack.github.io/.well-known/assetlinks.json`
- Pages build: `built`; public `true`; HTTPS enforced `true`
- no custom DNS, GitHub secret, Google provider, Supabase provider 또는 production 환경 변경

## Validation

| 검증 | 결과 |
|---|---|
| local public files → existing dev APK signer | PASS |
| GitHub repository visibility | PASS, public |
| GitHub Pages build | PASS, deployment commit `47b57e1` |
| live HTTPS contract | PASS, exact HTTPS path, 200, no redirect, JSON media type, bounded valid JSON, exact statement |
| Google Digital Asset Links API | PASS, `delegate_permission/common.handle_all_urls`, package `me.newlines.kinflow.dev`, expected SHA-256 |
| host-aware dev APK build gate | PASS, 216,121,761 bytes, SHA-256 `98ca27547f584125bd9c1d53cd73acbdb39071a9babb2a238196e7358aef623a` |
| rebuilt APK → local + live association | PASS |
| Android package signer | PASS, expected debug SHA-256 |
| Android domain verification | PASS, `adtstack.github.io: verified` |
| HTTPS invite dispatch | PASS, `LaunchState: COLD`, `me.newlines.kinflow.dev/me.newlines.kinflow.MainActivity` |

Detailed command evidence is in `logs/wp02-01-dev-pages-deployment.log`. The ignored `config/dev.local.json` supplied only the public dev host plus placeholder provider values; it was not committed or copied to the Pages repository.

## Security / Privacy

- Pages에는 `.well-known/assetlinks.json`, `.nojekyll`, no-index landing, `robots.txt`와 공개 README만 존재한다.
- Google/Supabase secret, token, email, invite 원문, cookie, publishable-key 값과 사용자 식별자는 log/evidence에 저장하지 않았다.
- Google Cloud 초기 설정의 정책 동의는 운영자의 명시적 동의가 필요해 체크하지 않았다.
- Supabase Google provider dialog의 브라우저 autofill 값은 저장하지 않고 취소한 상태를 유지한다.

## Remaining Risks / Completion Boundary

1. dev association은 현재 운영자의 debug keystore에만 유효하며 keystore 변경 시 statement rotation과 재검증이 필요하다.
2. production package와 Play App Signing delivery certificate는 포함하지 않았다.
3. Google OAuth clients, Supabase Google provider, remote session restore와 two-adult/two-device invite flow는 아직 미검증이다.
4. GitHub Pages public repository가 삭제·비공개 전환되거나 배포 파일이 drift하면 Android verified link가 깨진다.

This evidence completes substep `4-2a`. WP02-01 overall과 Phase 02 Exit Gate는 Google/Supabase provider token exchange와 실제 성인 2인·Android 2기기 시나리오 완료 전까지 미완료다.

## Rollback

- app repository에서 이 slice commit을 revert하면 public-site deploy metadata와 evidence를 제거할 수 있다.
- 외부 rollback은 GitHub Pages unpublish와 public repository archive/delete다. 이는 destructive external action이므로 별도 명시적 승인 없이 실행하지 않는다.
- DB migration, RLS, RPC 또는 backend data 변경은 없다.

## Next Entry Condition

1. 운영자가 Google API 사용자 데이터 정책을 직접 동의하고 Google 인증 플랫폼 생성을 완료한다.
2. dev Web OAuth client에는 Supabase callback을, Android client에는 `me.newlines.kinflow.dev`와 current SHA-1을 등록한다.
3. Supabase Google provider에 실제 client IDs와 Web client secret을 저장하고 nonce check를 유지한다.
4. ignored dev public config에 실제 Supabase public URL/key와 Google Web client ID를 적용해 로그인 및 invite continuation을 검증한다.
5. 성인 Google 계정 2개와 Android 기기 2대로 runbook을 완료한다.
