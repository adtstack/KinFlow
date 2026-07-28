# Public Site

공개 지원·개인정보·계정 삭제 사이트의 예약 경로다. Android Store 제출 전 별도 Work Package에서 구현하며 WP01-01에는 runtime scaffold를 만들지 않는다.

## Dev Android App Link Asset

`public/.well-known/assetlinks.json`은 현재 로컬 dev APK의 공개 association만 담는다.

- package: `me.newlines.kinflow.dev`
- signing source: 현재 운영자의 Android debug keystore
- 용도: owned dev invite host의 `/.well-known/assetlinks.json`
- prod 배포: 금지

Astro scaffold가 추가되면 `public/` 아래 파일은 경로를 바꾸지 않고 정적 asset으로 배포한다. 그 전에도 이 파일 자체를 dev host의 web root에 배포할 수 있다. 서버는 HTTPS 200, `Content-Type: application/json`으로 redirect 없이 응답해야 한다.

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
  <owned-dev-host>
```

다른 운영자 keystore나 signing key로 APK를 만들면 검증은 실패한다. 새 APK의 인증된 SHA-256으로 파일을 명시적으로 갱신하고 다시 검증한다. production association은 Play App Signing으로 사용자에게 전달되는 인증서가 확정되기 전에는 만들지 않는다.
