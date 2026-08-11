# KinFlow Public Site

KinFlow의 EN/KO 공개 약관, 개인정보, 지원과 계정 삭제 요청 경로를 제공하는 Astro 정적 사이트다. 브라우저 JavaScript, form backend, cookie, analytics와 tracker를 사용하지 않으며 `src/config/site-config.mjs`가 승인되지 않은 production publication을 fail closed한다. 환경 변수와 별개로 `src/config/policy-content-manifest.mjs`의 source-controlled 본문 상태도 `approved`여야 한다.

기본 development build는 `.invalid` origin/mailbox, `draft` 정책 상태와 `noindex`를 사용한다. production build는 `.env.example`의 모든 공개 값을 실제 owned origin, support mailbox, 법률 주체, 승인된 policy version/date로 명시해야 한다. 앱/API contract version을 legal policy version으로 재사용하지 않는다.

```bash
npm install --ignore-scripts --no-audit --no-fund
npm test
```

`npm test`는 정적 build, Astro type check, route/link/accessibility/security/privacy contract와 production configuration denial을 검증한다. 최종 법률 문구, owned domain/mailbox, 실제 email 전달과 hosted/browser/Store 검증 전에는 production 게시물을 만들지 않는다.

## Dev Android App Link Asset

`public/.well-known/assetlinks.json`은 현재 로컬 dev APK의 공개 association만 담고 GitHub Pages에 배포한다.

- package: `me.newlines.kinflow.dev`
- signing source: 현재 운영자의 Android debug keystore
- dev host: `https://adtstack.github.io`
- live association: `https://adtstack.github.io/.well-known/assetlinks.json`
- deploy repository: `adtstack/adtstack.github.io`, `main` branch root
- prod 배포: 금지

Astro는 `public/`을 정적 build output에 그대로 복사한다. `.nojekyll`은 well-known 경로를 보존하고 `_headers`는 지원하는 static host에 CSP와 privacy/security header를 제공한다. 사용자 데이터, analytics, credential 또는 production secret은 이 디렉터리에 두지 않는다. 서버는 association 파일을 HTTPS 200, `Content-Type: application/json`으로 redirect 없이 응답해야 한다.

배포 전 설치 APK와 exact package/signing fingerprint를 다시 비교한다.

```bash
scripts/verify-android-app-links.sh \
  dev \
  apps/kinflow_app/build/app/outputs/flutter-apk/app-dev-debug.apk \
  apps/public_site/public/.well-known/assetlinks.json
```

배포 후에는 마지막 argument로 DNS host만 전달해 local signer 비교와 live HTTPS 계약을 연속 검증한다.

```bash
scripts/verify-android-app-links.sh \
  dev \
  apps/kinflow_app/build/app/outputs/flutter-apk/app-dev-debug.apk \
  apps/public_site/public/.well-known/assetlinks.json \
  adtstack.github.io
```

다른 운영자 keystore나 signing key로 APK를 만들면 검증은 실패한다. 새 APK의 인증된 SHA-256으로 파일을 명시적으로 갱신하고 다시 검증한다. production association은 Play App Signing으로 사용자에게 전달되는 인증서가 확정되기 전에는 만들지 않는다.
