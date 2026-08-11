# KinFlow

KinFlow는 성인 2인이 가구를 만들고 집안일을 나누어 완료하는 Android-first 가족 협업 앱이다.

현재 local 구현은 가구 권한·온보딩·초대·구성원 lifecycle에 더해 Today 집안일과 Calendar 일정의 생성/완료·한 회차 예외·전체 시리즈 변경 및 선택 회차 기준 수정·취소까지 포함한다. 선택 회차 경계는 서버의 immutable recurrence slot이 결정하며, Calendar 취소는 경계 이후 moved exception까지 포함하고 이전 actionable prefix는 bounded terminal revision으로 보존한다. dev Google/Supabase provider와 owned App Link domain은 구성·검증했지만 실제 성인 계정·Android 두 기기 live gate와 production 배포는 마지막 검증 단계로 남아 있다. 자동 증거와 실제 계정·기기 증거는 구분한다.

## Accepted baseline

- Flutter SDK 3.44.7 / Dart SDK 3.12.2 exact pin
- Android Store MVP only
- production: `me.newlines.kinflow`
- dev: `me.newlines.kinflow.dev`
- dev/prod two environments
- Riverpod/go_router App Shell with safe startup recovery
- domain/application/data/presentation feature boundary with repository port/adapter DI
- Freezed/json_serializable DTO generation and drift verification
- Material 3 design token과 available-width 기반 compact/medium/expanded shell
- English/Korean Flutter gen_l10n과 test-only `en_XA` pseudo locale
- 48dp touch target, semantics, reduced-motion, RTL mirror, 200% text-scale smoke
- adult two-person activation slice
- exact allowlist 기반 공개 client config loader/validator
- PII-safe structured logger와 optional Sentry error boundary
- repository high-confidence secret scanner
- read-only/secret-free GitHub Actions quality·dependency·backend·Android gate
- checksum-pinned action/tool과 metadata egress 없는 offline vulnerability scan
- dev/prod debug APK metadata·permission·SHA-256 audit와 14일 artifact policy
- project-scoped Supabase CLI와 local PostgreSQL/RLS/Edge Function baseline
- 성인 2인 seed와 별도 household를 이용한 cross-household 격리 검증
- Flutter Supabase infrastructure adapter와 local health connectivity test
- Google native sign-in → Supabase Auth token exchange adapter와 secure logout purge; 공개 Web client ID가 없으면 fail-closed
- 가구·Owner membership·active selection을 한 transaction으로 만드는 첫 가구 온보딩
- hash-only 단일 사용 초대와 preview/accept/revoke Edge command, 로그인 전후 App Link continuation
- Admin/Member 역할 변경, 제거·나가기, 최근 인증 기반 Owner 이전과 immutable audit
- 반복 집안일의 한 회차 예외, 전체 시리즈 변경, 선택 회차 기준 수정·취소와 authoritative Today/Upcoming reconciliation
- 반복 Calendar의 한 회차 예외, 전체 시리즈 변경, 선택 회차 기준 수정·취소와 immutable recurrence-slot authority
- 독립 dev/prod Flutter Web release build, email-first sign-in과 no-PWA/no-persistent-cache capability fallback baseline

자세한 변경 근거는 `docs/adr/ADR-0002-android-first-release.md`를 따른다.

## Bootstrap

FVM을 사용하는 경우:

```bash
fvm install
fvm flutter --version
cd apps/kinflow_app
fvm flutter pub get
```

직접 설치한 SDK를 사용하는 경우 `KINFLOW_FLUTTER_BIN`에 Flutter 3.44.7 실행 파일을 지정한다.

```bash
export KINFLOW_FLUTTER_BIN=/absolute/path/to/flutter-3.44.7/bin/flutter
"$KINFLOW_FLUTTER_BIN" --version
cd apps/kinflow_app
"$KINFLOW_FLUTTER_BIN" pub get
```

버전 출력은 Flutter 3.44.7과 Dart 3.12.2여야 한다.

로컬 Supabase foundation을 실행하는 경우 Docker가 필요하다.

```bash
npm ci
npx supabase start
npm run supabase:reset
npm run supabase:test
npm run supabase:health
npm run supabase:flutter-health
```

마지막 명령은 `flutter`가 PATH에 있어야 한다. 다른 위치의 SDK는 `KINFLOW_FLUTTER_BIN=/absolute/path/to/flutter`로 지정할 수 있다. 로컬 publishable key는 실행 중인 stack에서 읽고 출력하거나 파일에 저장하지 않는다.

## Verify

```bash
cd apps/kinflow_app
fvm dart format --output=none --set-exit-if-changed lib test tool
fvm flutter analyze --fatal-infos --fatal-warnings
fvm flutter test
fvm dart run tool/verify_codegen.dart
fvm dart run tool/validate_public_config.dart
fvm dart run tool/scan_secrets.dart
fvm flutter build apk --debug --flavor dev --target lib/main_dev.dart --dart-define-from-file=config/dev.example.json
fvm flutter build apk --debug --flavor prod --target lib/main_prod.dart --dart-define-from-file=config/prod.example.json
```

예제 config는 공개 client 값만 정의한다. placeholder Supabase publishable key는 정적 예제 검증에는 허용되지만 runtime에서는 fail-closed 한다. `SENTRY_DSN`이 비어 있으면 Sentry SDK와 네트워크 전송은 시작하지 않는다.

실제 환경 파일, OAuth client secret, Supabase service role key, Sentry auth token, signing key는 커밋하지 않는다. 실제 provider와 성인 2인 기기 연결은 `docs/evidence/phase-02/GOOGLE_ANDROID_TWO_ADULT_RUNBOOK.md`를 따른다.

## CI

GitHub Actions는 PR, `main` push와 수동 실행에서 다음 job을 병렬 수행하고 단일 `CI gate`로 집계한다.

- format/analyzer/unit·widget·architecture/codegen/config/secret와 coverage report
- Pub/npm license allowlist와 OSV offline vulnerability scan
- Supabase reset/lint, 전체 pgTAP RLS/contract, Edge health와 Flutter live adapter contract
- Android dev/prod debug APK build와 package/API/permission/checksum audit
- Web dev/prod release build와 version/path URL/no-PWA/no-persistent-cache/checksum audit

PR workflow 권한은 `contents: read`뿐이며 production secret을 참조하지 않는다. action과 다운로드 도구는 release commit 또는 checksum으로 고정한다. OSV database는 공개 fixture로 받은 뒤 실제 lockfile scan을 network-disabled mode에서 실행한다. 실패한 Android build의 APK는 업로드하지 않는다.

로컬에서 CI 계약과 개별 gate를 재현할 수 있다.

```bash
npm run ci:test
npm run ci:workflow
scripts/ci/flutter-quality.sh
npm run ci:dependency
scripts/ci/supabase-backend.sh
scripts/ci/android-build.sh dev
scripts/ci/android-build.sh prod
scripts/ci/web-build.sh dev
scripts/ci/web-build.sh prod
```

Flutter package cache만 사용하는 검증은 `KINFLOW_PUB_OFFLINE=1`을 추가한다. Phase 02 상태 정합성 기준 원격 실행은 [CI run 30504563368](https://github.com/adtstack/KinFlow/actions/runs/30504563368)이며 모든 source job과 최종 `CI gate`가 통과했다. branch protection/ruleset 적용은 별도 repository 관리 작업으로 남아 있다.
