# Phase 02 WP02-01 Secure Storage Evidence

- Work Package: WP02-01 Auth lifecycle — Android secure storage and Supabase runtime composition
- 기준 commit: base `85be5b9`; implementation `fae115d`
- 검증일: 2026-07-28
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0
- 결과: **LOCAL + REMOTE AUTOMATED SECURE STORAGE PASS / ANDROID DEVICE·GOOGLE PENDING**
- 선행 근거: provider-independent auth foundation `LOCAL + REMOTE FOUNDATION PASS`

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP02-01 / FR-AUTH-004 | LOCAL AUTOMATED PASS / DEVICE PENDING | secure store readiness 뒤 Supabase를 초기화하고 실제 `ProviderAuthSessionRepository`를 runtime에 주입한다. 초기화 중에는 auth router를 만들지 않는다. |
| FR-AUTH-005 / D-049 | LOCAL AUTOMATED PASS | logout, revoked/invalid session, account switch가 사용하는 composite purger에 인증 전용 namespace 전체 삭제 participant를 등록했다. |
| CAP-001 | PARTIAL | Supabase session adapter는 runtime에 연결했고 Google sign-in launcher는 사용자 요청대로 unavailable 상태를 유지한다. |
| CAP-008 / T-SEC-03 | LOCAL AUTOMATED PASS / DEVICE PENDING | session과 PKCE verifier가 같은 환경별 Keystore-backed namespace를 사용하며 plain SharedPreferences fallback이 없다. 실제 Keystore forensic은 미실행이다. |
| T-AUTH-01 / T-CACHE-01 | PASS | storage CRUD/readiness, session/PKCE 격리, purge, runtime composition, loading/failure/retry와 protected router 차단 테스트가 통과했다. |
| Android backup contract | APK AUDIT PASS | dev/prod 최종 APK 모두 `android:allowBackup=false`; 권한 allowlist 증가 없음. |

## Implementation

- `FlutterSecureStringStore`가 `flutter_secure_storage`를 내부 port 뒤에 격리하고 readiness 및 CRUD를 fail-closed로 전달한다.
- `SupabaseSecureAuthStorage`가 Supabase session `LocalStorage`와 PKCE `GotrueAsyncStorage`를 모두 구현한다. provider key는 base64url 인코딩한 버전 key로 저장한다.
- dev/prod는 `kinflow_auth_dev_v1` / `kinflow_auth_prod_v1` namespace로 분리하고 RSA-OAEP SHA-256 key wrapping과 AES-GCM authenticated encryption을 명시한다.
- storage readiness가 성공한 뒤에만 `Supabase.initialize`를 실행한다. PKCE, token auto-refresh를 켜고 debug 및 승인되지 않은 URI session detection은 끈다.
- 초기화 성공 뒤 단일 root `ProviderScope`를 만들고 실제 Supabase session repository를 주입한다. 실패 시 raw exception 없이 startup failure로 닫고 retry를 제공한다.
- Google Cloud/Supabase provider, OAuth client, callback/App Link와 Google SDK는 추가하지 않았다. 로그인 버튼은 계속 disabled다.
- Android 앱 전체 OS backup을 비활성화하고 CI가 최종 APK의 binary manifest 및 권한을 감사한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| exact toolchain | Flutter 3.44.7 / Dart 3.12.2 / Node 24.15.0 확인 |
| `npm run ci:test` | PASS 9/9 |
| workflow contract + actionlint | PASS, 5 jobs / pinned action 17 / `contents:read` |
| Dart format | PASS, 97 files / drift 0 |
| fatal Flutter analyze | PASS, issue 0 |
| full Flutter suite with coverage | PASS, 101 tests + local connectivity opt-in 1 skip |
| coverage summary | 1,273/1,499 lines, 84.92% |
| public config / secret / codegen / architecture | PASS; high-confidence secret 0, generated drift 0 |
| dependency license audit | PASS, 143 Pub / 15 npm packages |
| OSV-Scanner 2.3.8 offline vulnerability scan | PASS, exact lockfiles only, actual scan network disabled |
| Android dev debug APK | PASS, `me.newlines.kinflow.dev`, 215,866,132 bytes, SHA-256 `8ca208b263a67eb32b98265ebda79d9db92bcc17111ab39393278e8013c65ab9` |
| Android prod debug APK | PASS, `me.newlines.kinflow`, 215,866,043 bytes, SHA-256 `e5d294e8fa6b5ffea2427bc340a9deb53fdbed0ec43e460e80560c8c4afe84e1` |
| final APK manifest / permissions | PASS, backup disabled; `INTERNET` + package-scoped dynamic receiver only |
| GitHub Actions CI | PASS, run `30342570943`; quality, dependency, backend, dev/prod APK와 final gate 성공 |

상세 실행 요약은 `logs/wp02-01-secure-storage.log`에 있다. CI report, coverage와 APK 원본은 ignored local artifact이며 repository에는 session, token, provider payload 또는 credential을 추가하지 않았다.

Remote run: <https://github.com/adtstack/KinFlow/actions/runs/30342570943>

## Dependency Review

- [`flutter_secure_storage` 10.3.1](https://pub.dev/packages/flutter_secure_storage)을 compatible range로 선언하고 lockfile에서 exact patch와 checksum을 고정했다.
- direct package와 platform adapter는 dependency audit에서 BSD-3-Clause로 판정됐고 전체 허용 라이선스 게이트를 통과했다.
- package Android min API 23은 앱 min API 24와 호환된다. 새 runtime permission, network client 또는 telemetry를 추가하지 않는다.
- Flutter 표준 SDK에는 Android Keystore-backed cross-platform key-value API가 없고, Supabase 기본 SharedPreferences persistence는 token 저장 계약을 만족하지 않아 채택하지 않았다.
- 직접 MethodChannel/암호 lifecycle을 구현하는 대안은 migration, key invalidation과 authenticated-encryption 오류 가능성이 더 커서 배제했다.
- rollback은 runtime composition과 adapter를 unavailable repository로 되돌리고 dependency/lockfile, backup manifest와 APK audit를 함께 revert한다.

## Security / Privacy

- access/refresh session과 PKCE verifier는 인증 전용 secure namespace 밖에 저장하지 않는다. dev/prod namespace를 공유하지 않는다.
- Android storage option은 RSA-OAEP SHA-256 + AES-GCM, algorithm migration, crash-resistant migration backup과 corrupt-key reset을 명시한다. 앱 OS backup은 전체 비활성화한다.
- logout/account switch/revocation purge는 session key만이 아니라 인증 namespace 전체를 삭제한다.
- Supabase debug logging과 승인되지 않은 deep-link session detection을 끄고 initialization error는 stable code만 기록한다.
- token, 이메일, provider exception message는 domain state, 화면, structured log와 evidence에 노출하지 않는다.

## Manual / Device Validation

- `adb devices -l`: 연결 기기 0대. 실제 Android Keystore 생성, encrypted-at-rest 확인, process death/cold restore, reinstall, backup/restore, corrupted-key recovery는 **NOT RUN**이다.
- 실제 dev Supabase project/key를 사용한 remote session restore/refresh는 **PENDING**이다. 공개 설정 loader와 SDK composition까지만 자동 검증했다.
- 실제 성인 계정 2개, Google OAuth package/SHA, Supabase Google provider, nonce/ID-token exchange와 callback/App Link는 사용자 결정대로 **PENDING**이다.

## Remaining Risks / Completion Boundary

1. 이 결과는 WP02-01의 secure-storage/runtime vertical slice 완료이며 WP02-01 전체 provider/device 완료가 아니다.
2. Google launcher가 unavailable이므로 앱은 의도적으로 로그인할 수 없다. disabled 상태를 성공 mock으로 취급하지 않는다.
3. 연결 기기가 없어 Android Keystore lifecycle과 backup/reinstall forensic을 확인하지 못했다.
4. 앱의 실제 dev Supabase configuration이 없으면 remote session restore와 refresh 성공을 입증할 수 없다.
5. Flutter 3.44 Android 빌드는 기존 `sentry_flutter`의 향후 Built-in Kotlin 전환 경고를 내지만 현재 dev/prod 빌드는 통과했다. 별도 dependency 유지보수 항목이다.

## Rollback

- secure storage port/driver, Supabase storage/initializer, auth runtime gate와 composition 변경을 함께 revert한다.
- `flutter_secure_storage` 선언과 lockfile transitive package, toolchain contract를 함께 제거한다.
- `android:allowBackup=false`와 APK audit를 함께 되돌리되 secure session persistence가 남아 있는 상태에서는 backup을 다시 켜지 않는다.
- DB/API/remote provider/credential을 변경하지 않았으므로 migration 또는 remote-console rollback은 없다.

## Next Entry Condition

- implementation commit `fae115d`와 GitHub Actions run `30342570943`의 모든 required job 및 final gate가 확인됐다.
- 실제 Google sign-in은 dev Google/Supabase provider, exact `me.newlines.kinflow.dev` package/SHA, approved callback/domain, Android device와 성인 테스트 계정이 준비된 뒤 별도 slice로 시작한다.
- 그 전에는 WP02-01 전체 PASS 또는 실제 device PASS를 선언하지 않는다.
