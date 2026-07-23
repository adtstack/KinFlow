# 28. CI/CD, 환경, Release 구현 스펙

- 상태: ACCEPTED

## 1. Branch와 environment

- pull request: untrusted, production secret 없음
- main: dev artifact와 docs
- release/*: prod application ID의 Play internal/closed RC
- production environment: 보호 승인과 최소 secret

## 2. CI jobs

### Fast checks

- format
- analyze fatal warnings
- unit/widget tests
- codegen drift
- secret/license/dependency scan
- Markdown/contract validation

### Backend

- Supabase local start/reset
- migration/lint
- pgTAP/RLS matrix
- Edge Function contract test

### Platform

- Android debug/build
- integration smoke

### RC

- signed IPA/AAB
- artifact checksum/SBOM/provenance
- staging deploy
- manual approval
- Fastlane upload

## 3. Reproducibility

- Flutter exact version via FVM 또는 CI action pin
- `pubspec.lock` commit
- Java/Ruby/CocoaPods/CLI version record
- clean checkout build
- build number source of truth
- environment config checksum

## 4. Configuration

공개 client config:

- Supabase URL/publishable key
- RevenueCat public SDK key
- Sentry DSN
- environment name
- public website/API origin

비밀:

- service role
- webhook secrets
- APNs/server credential
- store API key/private key
- signing keystore/password

비밀을 `--dart-define`이나 repository 파일로 전달하지 않는다.

## 5. Flavor

- Dart entrypoint + native scheme/build variant
- unique display suffix/icon for dev
- separate Firebase config
- separate deep link hosts 또는 path
- production에서 debug menu/verbose log 제거

## 6. Fastlane

권장 lane:

```text
android internal / android release / android metadata
```

Fastlane action과 gem version을 lock하고 CI만으로도 재현 가능하게 한다. 초기에는 자동 production rollout보다 upload + human approval을 사용한다.

## 7. DB deployment

- 앱 binary보다 먼저 backward-compatible expand migration
- new feature flag off
- client rollout
- metrics 확인
- contract migration은 old client 비중 감소 후
- migration failure 시 forward recovery

## 8. Remote config

허용:

- feature flag
- safe limits/copy subset
- minimum supported version
- kill switch

금지:

- Store review를 우회하는 실행 코드 다운로드
- 보안/결제 invariant 변경
- 비밀 전달

## 9. Web deploy

- immutable hashed assets
- atomic deploy
- cache headers 분리
- API contract compatibility
- rollback revision
- CSP/security headers test

## 10. Evidence

- workflow run URL
- commit SHA/tag
- toolchain versions
- test/build reports
- artifact checksum
- signer identity
- migration list
- approval and rollout status
