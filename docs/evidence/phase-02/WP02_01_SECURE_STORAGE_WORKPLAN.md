# Phase 02 WP02-01 Secure Storage Work Plan

- 작성일: 2026-07-28
- 기준 commit: `85be5b9`
- Work Package: WP02-01 Auth lifecycle — Android secure storage and Supabase runtime composition
- 상태: COMPLETE — LOCAL AUTOMATED SLICE PASS / ANDROID DEVICE·GOOGLE PENDING
- 선행 결과: provider-independent auth foundation `LOCAL + REMOTE FOUNDATION PASS`

## Requirements

| ID | 이번 vertical slice |
|---|---|
| WP02-01 / FR-AUTH-004 | 검증된 공개 dev/prod 설정으로 Supabase client를 초기화하고 secure store의 session을 기존 lifecycle repository에 연결한다. |
| FR-AUTH-005 / D-049 | logout, invalid session, account switch purge에 인증 전용 secure-storage namespace 전체 삭제를 포함한다. |
| CAP-001 | `SupabaseAuthSessionDataSource`를 runtime composition에 연결하되 Google sign-in launcher는 unavailable 상태를 유지한다. |
| CAP-008 / T-SEC-03 | Android Keystore-backed 저장소에 access/refresh session과 향후 PKCE verifier를 저장하고 plain SharedPreferences persistence를 사용하지 않는다. |
| T-AUTH-01 / T-CACHE-01 | storage CRUD/namespace, initialization failure, retry, session repository composition과 purge를 자동 테스트한다. |
| Android backup contract | Keystore key 없이 암호문만 복원되는 상황을 차단하도록 앱 auto backup을 비활성화하고 manifest 계약을 자동 검증한다. |

## Scope

1. `flutter_secure_storage`를 compatible range로 추가하고 `pubspec.lock`에서 정확한 patch를 고정한다.
2. plugin을 감싸는 내부 secure string-store driver를 두어 SDK와 테스트를 분리한다.
3. Supabase `LocalStorage`와 `GotrueAsyncStorage`를 모두 구현하는 인증 전용 adapter를 추가한다.
4. dev/prod별 격리 namespace를 사용하고 session/PKCE key를 버전이 포함된 내부 key로 한정한다.
5. storage readiness 이후에만 Supabase를 초기화하고 실제 `ProviderAuthSessionRepository`를 앱에 주입한다.
6. 초기화 중에는 auth router를 만들지 않으며 실패 시 raw exception 없이 startup failure로 닫고 재시도를 허용한다.
7. secure auth namespace purge participant를 기존 composite purger에 등록한다.

## Explicit Non-scope

- Google Cloud/Supabase Google provider, Google SDK, nonce/ID-token 교환
- OAuth callback, App Link/redirect manifest intent filter
- 실제 성인 계정 2개 로그인 및 Android process-death/device forensic test
- household schema/RLS, profile bootstrap, FCM/RevenueCat identity

## Dependency Review

| 항목 | 결정 |
|---|---|
| package | `flutter_secure_storage` 10.3.x compatible range, lockfile exact resolution |
| 목적 | Android Keystore-backed access/refresh session과 향후 PKCE verifier persistence |
| 표준 SDK 대안 | Flutter 표준 library에는 Android Keystore-backed cross-platform key-value API가 없다. 직접 MethodChannel/암호 구현은 key lifecycle과 migration 위험이 더 크다. |
| 거부 대안 | Supabase 기본 SharedPreferences storage는 token 저장 요구를 만족하지 않는다. deprecated Jetpack `EncryptedSharedPreferences` 강제 사용도 채택하지 않는다. |
| 플랫폼 | package는 Android/iOS/macOS/Web/Windows/Linux를 지원하지만 이 slice의 runtime 및 Gate는 Android dev/prod만 승인한다. Android min API 23 요구는 앱 min API 24와 호환된다. |
| 유지보수 | 2026-07-28 기준 stable 10.3.1, 최근 Android cipher/migration 변경이 유지보수되고 있다. |
| license | BSD-3-Clause. dependency/license audit 결과를 evidence에 기록한다. |
| privacy/network | on-device encrypted storage만 사용하며 자체 network/telemetry를 추가하지 않는다. token을 log/evidence/domain state에 넣지 않는다. |
| native 영향 | Android plugin binary가 추가되며 runtime permission은 추가하지 않는다. `android:allowBackup=false`를 추가한다. |
| testability | plugin 뒤에 내부 driver를 두고 memory fake로 storage/Supabase composition/purge를 검증한다. |
| rollback | composition과 adapter를 제거하고 unavailable repository로 되돌린 뒤 dependency/lockfile과 backup manifest 변경을 함께 revert한다. |

## Security Contract

- Android 기본 RSA-OAEP key wrapping과 AES-GCM authenticated encryption을 사용한다.
- biometric prompt는 로그인 세션의 background refresh를 방해하므로 이번 slice에서 요구하지 않는다.
- 인증 전용 storage namespace는 environment별로 분리한다.
- algorithm migration은 crash-resistant backup option을 사용하되 Android OS backup 대상에서는 전체 앱을 제외한다.
- secure storage read/write/delete 실패는 startup 또는 purge failure로 fail-closed하며 raw plugin exception을 UI/log에 전달하지 않는다.
- Supabase debug logging과 unapproved deep-link session detection은 비활성화한다.

## Automated Validation

- secure driver의 environment namespace와 Android cipher option 계약
- Supabase session persistence/restore/remove 및 PKCE key isolation
- namespace purge가 session과 PKCE 값을 모두 삭제
- storage/Supabase initialization failure 시 protected router 미생성, startup failure 표시, retry 성공
- 실제 repository composition 후 session 없음은 Google-only disabled sign-in으로 이동
- Android manifest backup-disabled 및 permission allowlist 유지
- format, fatal analyze, full Flutter suite, secret/config/codegen/architecture, dependency/license audit
- dev/prod Android debug APK build와 manifest/permission audit

## Data / API Impact

- DB migration, seed, RLS, RPC, Edge/API contract 변경 없음.
- Supabase URL/publishable key는 기존 검증된 public configuration만 사용한다.
- server secret, Google credential, signing material, remote provider 설정 변경 없음.

## Manual / Deferred Validation

- 연결 Android가 없으면 Keystore 생성, reinstall, OS backup/restore, process death와 corrupted-key recovery는 `NOT RUN`으로 기록한다.
- 실제 dev Supabase project/key가 없으면 remote session restore/refresh는 `PENDING`으로 유지한다.
- Google 로그인은 사용자 요청대로 후속 slice다.

## Stop / Rollback

- token이 plain preferences/log/test evidence에 나타나거나 환경 namespace가 섞이면 즉시 중단한다.
- 초기화 실패 뒤 보호 route가 만들어지거나 purge 실패 뒤 세션 route가 열리면 다음 작업으로 진행하지 않는다.
- dependency, secure-storage adapter, Supabase composition, startup gate, auth dependency wiring과 Android backup attribute를 함께 revert하면 이전 unavailable/fail-closed 상태로 복귀한다.

## Next Entry Condition

- local/remote automated gate와 dev/prod APK가 green이어도 실제 Keystore/device forensic 항목은 별도로 남긴다.
- 그 다음 Google sign-in slice는 dev provider/client/package SHA, redirect/domain, Android device와 성인 테스트 계정 준비 후에만 시작한다.
