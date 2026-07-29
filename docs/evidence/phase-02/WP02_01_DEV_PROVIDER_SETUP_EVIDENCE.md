# Phase 02 WP02-01 Dev Provider Setup Evidence

- Work Package: WP02-01 — real dev Google Android / Supabase Auth provider
- 기준 commit: base `c43e78f`
- 검증일: 2026-07-29
- 환경: Google Cloud project `kinflow-503900`; Supabase project ref `ghsniwhntbjofvslfxeq`; Android API 36 `sdk_gphone64_arm64`
- 결과: **EXTERNAL PROVIDER CONFIG + PUBLIC SETTINGS + ACTUAL-CONFIG APK PASS / REAL GOOGLE LOGIN PENDING**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| FR-AUTH-003 / D-054 | READY, TOKEN EXCHANGE NOT RUN | Google native client와 Supabase Google provider가 실제 dev public config에 연결됐지만 사용자 token은 아직 발급하지 않았다. |
| FR-AUTH-004 | CONFIG PASS | exact Supabase callback, Android package/SHA-1, Web-first client audience 목록과 current verified App Link host를 연결했다. |
| FR-AUTH-005 / D-049 | AUTOMATED CONTRACT PASS / DEVICE FLOW NOT RUN | 기존 purge/account-switch tests는 유지되며 실제 계정 chooser/logout은 다음 gate다. |
| Security | PASS | Web client secret은 Supabase server-side에만 저장했고 app/Git/log/evidence에는 client ID suffix와 공개 binding만 기록했다. |

## Google Auth Platform

- branding: `KinFlow Dev`
- audience: External, testing
- test users: 운영자가 직접 선택한 support account 1명 등록; 이메일 값은 기록하지 않음
- Web OAuth client: `KinFlow Dev Web`, 식별 suffix `6egjf4`
- authorized redirect URI: `https://ghsniwhntbjofvslfxeq.supabase.co/auth/v1/callback`
- Android OAuth client: `KinFlow Dev Android`, 식별 suffix `sqbuf2`
- Android package: `me.newlines.kinflow.dev`
- Android signing SHA-1: `A2:12:1B:14:AA:68:34:21:B5:C5:81:B7:61:F1:B1:3C:AF:DC:24:8D`
- broad Google API scope, service account, Firebase 또는 `google-services.json`은 추가하지 않았다.

Google Project Checkup의 `Use secure flows` warning은 남아 있다. 앱은 native Google Identity flow를 사용하고 embedded webview를 사용하지 않지만, unpublished dev APK라 Google Play Android app ownership verification은 아직 수행할 수 없다. production Play App Signing과 app ownership verification 전에는 이 경고를 해결 완료로 선언하지 않는다.

## Supabase Auth

- Google provider: enabled
- Client IDs: Web first, Android second
- Web client secret: dashboard server-side only
- `skip_nonce_check`: false
- allow provider users without email: false
- user signups: enabled
- manual linking: disabled
- anonymous sign-in: disabled
- browser autofill이 넣은 기존 값은 저장하지 않고 즉시 지운 뒤 실제 생성 client로 교체했다.
- public `/auth/v1/settings` live probe: Google enabled PASS

공식 Supabase 문서가 multiple client ID를 comma-separated로 등록하고 Web client ID를 첫 번째에 둘 것을 요구하므로 현재 순서를 사용한다.

- <https://supabase.com/docs/guides/auth/social-login/auth-google>
- <https://supabase.com/docs/reference/dart/auth-signinwithidtoken>
- <https://support.google.com/cloud/answer/15548748?hl=en>

## Local Public Config And APK

- ignored file: `apps/kinflow_app/config/dev.local.json`, local mode `0600`
- exact public key allowlist: PASS
- values present: Supabase project URL, publishable key, Google Web client ID, public site URL와 App Link host
- values absent: Google client secret, Supabase service-role/secret key, token, email와 account identifier
- actual-config dev APK build: PASS, 216,121,931 bytes
- APK SHA-256: `6b900e88ad8bc4a9f71b31ade5e10140efd84663c56af536874056c69803993a`
- local + live association: PASS
- Android OS domain state: `adtstack.github.io: verified`
- app bootstrap: PASS, `LaunchState: COLD`, `me.newlines.kinflow.dev/me.newlines.kinflow.MainActivity`

## Automated Validation

| 검증 | 결과 |
|---|---|
| repository Node tests | PASS, 26/26; Supabase live-provider success/failure 4개 포함 |
| public settings probe | PASS, exact HTTPS settings endpoint and `external.google=true` |
| public config allowlist | PASS |
| actual-config Android build gate | PASS |
| APK signer → local/live association | PASS |
| Android OS verified App Link | PASS |
| real Google account chooser and token exchange | NOT RUN |
| Supabase session and protected route | NOT RUN |
| logout/account switch purge on device | NOT RUN |

Detailed command evidence is in `logs/wp02-01-dev-provider-setup.log`. Public settings validation never prints the publishable key or response body and caps the response at 64 KiB.

## Security / Privacy / External State

- created external state: Google Auth external testing configuration, one Web client, one Android client and one test user; Supabase Google provider enablement.
- no client secret, publishable-key value, email, token, cookie, OAuth JSON download 또는 invite 원문을 저장·출력·커밋하지 않았다.
- `config/dev.local.json`은 ignored local file이며 Git status와 repository commit에 포함되지 않는다.
- DB migration, RLS, RPC, Edge/API와 customer data 변경은 없다.

## Remaining Risks / Completion Boundary

1. dashboard와 public settings 성공은 실제 Google ID token audience와 Supabase token exchange 성공을 증명하지 않는다.
2. 운영자 테스트 계정 1명만 등록됐고 두 번째 성인 계정은 아직 없다.
3. Google 설정 반영은 수 분 이상 걸릴 수 있어 첫 로그인 직후 propagation failure가 날 수 있다.
4. Play 배포 전 Android app ownership와 production signing client는 미완료다.

This evidence completes external substep `4-2b` and actual public-config build readiness. WP02-01 overall, `4-2c`와 Phase 02 Exit Gate는 real Google login, Supabase session과 two-adult/two-device E2E 완료 전까지 미완료다.

## Rollback

1. Supabase Google provider를 disable한다.
2. dev Web/Android OAuth clients를 disable한다.
3. ignored `config/dev.local.json`을 placeholder/local-only 값으로 되돌린다.

OAuth client 삭제와 project/repository 삭제는 destructive external action이므로 별도 명시적 승인 없이 실행하지 않는다. DB rollback은 없다.

## Next Entry Condition

1. 에뮬레이터 또는 실제 Android 기기에서 등록된 테스트 계정으로 Google 로그인한다.
2. Google ID token → Supabase session, secure persistence와 protected route를 확인한다.
3. logout/account chooser 재표시와 prior household/local cache purge를 확인한다.
4. 두 번째 성인 테스트 계정을 Audience에 추가하고 Android 2기기로 invite create/accept/cold-start/replay 시나리오를 완료한다.
