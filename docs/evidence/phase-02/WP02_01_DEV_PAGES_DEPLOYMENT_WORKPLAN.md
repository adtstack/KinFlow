# Phase 02 WP02-01 Dev Pages Deployment Work Plan

- 작성일: 2026-07-29
- 기준 commit: `4ef94e7`
- Work Package: WP02-01 / WP02-04 — owned dev App Link host deployment
- 상태: COMPLETE
- 외부 변경 승인: 사용자 승인 — `pages 공개저장소 생성 승인`

## Requirements

| ID | 이번 vertical slice |
|---|---|
| FR-AUTH-004 / FR-FLT-006 | Android dev package가 신뢰할 수 있는 root HTTPS host에서 exact Digital Asset Links statement를 읽게 한다. |
| WP02-04 / T-LINK-01 / T-LINK-02 | `https://adtstack.github.io/.well-known/assetlinks.json`이 redirect 없이 `application/json` 200으로 현재 dev APK package/signature와 일치해야 한다. |
| Security / Privacy | public package name과 certificate fingerprint 외에 key, token, email, account/project private metadata와 사용자 데이터를 공개하지 않는다. |

## Scope

1. user-site 규칙에 맞는 public repository `adtstack/adtstack.github.io`를 생성한다.
2. current source-of-truth `assetlinks.json`, `.nojekyll`, no-index landing page와 `robots.txt`만 배포한다.
3. GitHub Pages를 `main` branch root에서 publish하고 HTTPS endpoint를 기다린다.
4. repository visibility, Pages URL, HTTP status/content type/no redirect와 exact body를 검증한다.
5. current dev APK signer wrapper, Google Digital Asset Links API와 Android OS domain verification을 순서대로 실행한다.
6. 검증된 host를 dev runtime config/Android manifest의 `AUTH_REDIRECT_HOST`로 사용한다.

## Explicit Non-scope

- production host 또는 Play App Signing association
- commercial landing page, 결제, 사용자 계정 또는 개인정보 처리
- Google OAuth/Supabase provider mutation은 다음 `4-2b` substep에서 별도 검증한다.
- 성인 2계정·Android 2기기 E2E는 provider와 OS verified link 이후 실행한다.

## External State

- create: public GitHub repository `adtstack/adtstack.github.io`
- publish: GitHub Pages from `main` `/`
- public files: `.well-known/assetlinks.json`, `.nojekyll`, `index.html`, `robots.txt`, repository README
- no DNS purchase/change, no custom domain, no GitHub secret

## Validation

- GitHub repository visibility is `PUBLIC`
- Pages build/deployment success and exact public URL
- `scripts/verify-android-app-links.sh dev <apk> <local-file> adtstack.github.io`
- direct HTTP contract: HTTPS 200, no redirect, `application/json`, body at most 64 KiB
- Google Digital Asset Links statement API result
- `adb shell pm verify-app-links --re-verify me.newlines.kinflow.dev`
- `adb shell pm get-app-links me.newlines.kinflow.dev` domain state `verified`
- repository tests, full Flutter quality and remote CI after local source/evidence commit

## Stop / Rollback

- public endpoint가 redirect, HTML content type, stale signer 또는 unexpected statement를 반환하면 app config를 바꾸지 않는다.
- Pages repository에는 공개 association metadata 외 내용을 올리지 않는다.
- rollback은 Pages unpublish 후 public repository archive/delete 또는 statement 제거다. 외부 삭제는 별도 명시적 승인 없이 실행하지 않는다.
- DB/API/provider migration은 없으므로 database rollback은 없다.

## Completion Boundary

- public endpoint와 Android OS `verified`가 모두 확인돼야 `4-2a`를 완료한다.
- Google provider token exchange와 two-adult flow는 이 slice 성공만으로 완료로 선언하지 않는다.

## Completion Result

- public repository `adtstack/adtstack.github.io`와 GitHub Pages `main /` 배포를 생성했다.
- live HTTPS contract, Google Digital Asset Links API, dev APK signer 대조와 Android API 36 OS `verified`를 통과했다.
- 검증된 HTTPS invite는 KinFlow dev `MainActivity`를 cold start했다.
- 상세 결과와 rollback 경계는 `WP02_01_DEV_PAGES_DEPLOYMENT_EVIDENCE.md`에 기록한다.

## Official References

- <https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages>
- <https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site>
- <https://developer.android.com/training/app-links/configure-assetlinks>
- <https://developer.android.com/training/app-links/verify-applinks>
