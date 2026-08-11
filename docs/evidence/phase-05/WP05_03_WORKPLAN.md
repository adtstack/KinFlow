# Phase 05 WP05-03 Device Registration Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-08)`
- 범위: 실제 FCM/APNs SDK에서 공급될 provider token을 설치 identity와 현재 auth user/household/member에 안전하게 bind하고, token rotation, response-loss replay, logout/account switch/member removal revoke와 provider invalid-token 정리를 독립적으로 테스트 가능하게 만든다.
- 제외: Firebase/APNs project 설정과 실제 token 획득, OS permission prompt, provider send/receipt, foreground/background/terminated presentation, notification tap deep link와 실계정·실기기 검증(WP05-04 및 마지막 Gate)

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP05-03 / FR-NOTIF-002 | environment별 secure installation UUID를 앱 설치 동안 유지한다. provider token은 server Edge에서 AES-GCM으로 seal하고 SHA-256 fingerprint만 dedupe에 사용한다. token rotation은 같은 user/installation/channel endpoint 한 건을 versioned upsert한다. |
| WP05-03 / API-021 | registration UUID와 expected version으로 initial register, metadata refresh, token rotation과 response-loss replay를 구분한다. 같은 active token이 다른 계정에 재등록되면 과거 binding을 먼저 revoke한다. |
| WP05-03 / API-022 / D-049 | logout, session expiry/revoke, account switch에서 local binding secret으로 endpoint를 revoke한 뒤 account-bound local state를 제거한다. installation UUID는 계정과 무관하게 유지한다. member removal은 DB trigger로 해당 household binding을 즉시 revoke한다. |
| WP05-03 / T-PUSH-05 | provider invalid-token 결과는 endpoint ID와 expected token fingerprint가 모두 일치할 때만 active binding을 revoke한다. 회전 전 token의 늦은 failure가 새 token을 끄지 못한다. |
| NFR-SEC-01 / NFR-SEC-02 | raw token/secret/ciphertext/fingerprint table은 client와 direct service-role read를 거부한다. registration Edge가 verified auth user를 service RPC에 bind하며 unauthenticated revoke는 256-bit binding secret proof만 허용한다. server encryption key는 Flutter/web bundle에 없다. |
| NFR-PRIV-01 | client response, audit, log/error에는 raw token, ciphertext, fingerprint, revocation secret, email, content가 없다. endpoint metadata는 installation/channel/platform/permission/version/timestamp와 routing IDs만 반환한다. |
| NFR-REL-01 / NFR-COMP-01 | duplicate/retry/concurrent token ownership과 revoke replay가 멱등이다. WP05-01/02 worker/inbox와 기존 auth/household/Chore/Calendar API를 additive migration과 optional token-source boundary로 유지한다. |

## Data and API Impact

- `public.notification_endpoints`: user/household/member, installation UUID, native channel/platform, encrypted token envelope/key version, fingerprint, revocation-secret hash, permission/runtime metadata, lifecycle/version을 저장한다.
- `app_private.notification_endpoint_events`: `registered|refreshed|rotated|revoked`와 allowlisted reason/version만 immutable하게 기록한다.
- authenticated mediated API:
  - `get_notification_endpoint_status(installation_id)` — 현재 사용자 metadata-only status
- service-role-only APIs:
  - `upsert_notification_endpoint(...)` — verified identity와 server-sealed token의 versioned registration
  - `revoke_notification_endpoint_by_secret(...)` — logout/account-switch proof revoke
  - `invalidate_notification_endpoint(...)` — provider invalid-token fingerprint-guarded revoke
- Edge Function `notification-endpoint`:
  - authenticated `POST` registration
  - binding-secret proof `DELETE` revoke
- Flutter:
  - secure installation/binding store, UUID/secret generator
  - strict endpoint data source/repository/lifecycle controller
  - auth purge participant가 remote revoke 성공 후 account-bound binding만 제거

## Verification

- schema/check/index/FK/RLS/grant/security-definer/search-path/audit exact pgTAP
- initial register, exact replay, idempotency reuse, expected-version conflict, same-token refresh, token rotation, cross-account token reassignment
- wrong/correct secret revoke, revoke replay, stale/current fingerprint invalidation, member-removal auto revoke, recipient status isolation
- Edge exact body/auth/idempotency/CORS/error envelope, AES-GCM nondeterministic ciphertext, stable token/secret hash, raw-token non-reflection
- Flutter installation persistence, binding-only purge, response-loss recovery, rotation/version, authorization/failure mapping, strict DTO and dependency composition
- clean reset, focused/full pgTAP, DB lint, full repository JavaScript/Flutter regression, analyzer/formatter/config/secret/codegen/matrix/whitespace

## Security and Privacy

- mobile에는 public Supabase configuration만 남긴다. `KINFLOW_NOTIFICATION_TOKEN_ENCRYPTION_KEY`와 service role은 Edge server environment에서만 읽는다.
- token은 Edge memory에서 seal/hash한 뒤 raw form을 RPC/DB response/log로 전달하지 않는다. DB는 ciphertext와 fingerprint/hash를 client roles 및 direct service role에 노출하지 않는다.
- revoke secret은 secure storage와 one-way server hash에만 존재한다. installation UUID만으로 revoke할 수 없고 DELETE 응답은 endpoint 존재 여부를 노출하지 않는다.
- member removal, account switch, token reassignment과 provider invalidation은 stable reason만 audit하며 content/identity display data를 복제하지 않는다.

## Rollback

- 실제 provider send가 아직 없으므로 endpoint registration Edge/provider composition을 중지하고 Flutter token-source 호출을 비활성화해 기능을 격리한다.
- production 전에는 migration, Edge, Flutter lifecycle, tests/contracts를 함께 revert한다.
- production 후에는 applied migration을 수정하지 않는다. forward migration으로 registration/invalidation execute를 revoke하고 active endpoints를 allowlisted rollback reason으로 revoke하며 ciphertext/audit는 retention 승인까지 보존한다.

## Completion Boundary

- synthetic provider token으로 DB/Edge/Flutter lifecycle과 전체 회귀가 green이면 WP05-03 local slice를 완료한다.
- 실제 Firebase/APNs token acquisition/send/permission/app lifecycle은 WP05-04에 남긴다.
- hosted와 실제 계정·실기기 검증은 사용자 지시에 따라 대다수 기능 개발 뒤 마지막 Gate에서 수행한다.

2026-08-08 local automated gate는 clean 27-migration reset, focused 58/58 및 full 32-file/1,811 pgTAP, DB lint, Edge 13/13와 repository JavaScript 76/76, focused Flutter 25/25 및 full 497 tests(+ opt-in 1 skip), analyzer/formatter/config/secret/codegen/dependency/workflow/matrix/whitespace checks를 통과했다. 상세 결과와 deferred 범위는 `WP05_03_EVIDENCE.md`에 기록한다.
