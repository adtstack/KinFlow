# Phase 05 WP05-04 Android Mobile Push Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-08)`
- 범위: WP05-02 durable inbox와 WP05-03 encrypted endpoint 사이에 Android FCM 전송 worker를 연결하고, 앱에서 명시적 pre-prompt, Android notification permission, token/rotation binding, foreground local presentation, background/terminated tap continuation과 서버 재인가를 독립적으로 테스트 가능하게 만든다.
- 제외: 실제 Firebase project/service account와 실계정·실기기 provider send, hosted scheduler, OEM별 background 동작, iOS/APNs, Web Push, provider outage alert/SLO drill(WP05-05 및 마지막 Gate)

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP05-04 / FR-NOTIF-001 / FR-FLT-007 | 앱 첫 실행에서 OS prompt를 띄우지 않는다. 알림 설정에서 목적·개인정보 최소화·인앱 fallback을 설명한 pre-prompt의 명시적 action 뒤에만 Android permission을 요청한다. denied 상태는 설정 이동과 durable inbox를 제공한다. |
| WP05-04 / FR-NOTIF-002 / D-049 | permission granted와 유효 FCM token이 모두 있을 때만 기존 `NotificationEndpointLifecycle`에 현재 user/household, Android platform, locale/timezone/runtime metadata를 bind한다. token rotation, household/account switch와 logout purge를 기존 crash-safe lifecycle에 위임한다. |
| WP05-04 / FR-NOTIF-003 / D-022 / D-023 | server worker가 `delivery_not_before`, 최신 inbox cancellation, 현재 preference, active membership와 active Android endpoint를 원자적으로 다시 검사한 delivery만 claim한다. 클라이언트 background 실행은 정확성의 근거가 아니다. |
| WP05-04 / FR-NOTIF-005 | foreground/background/terminated 또는 local notification tap payload를 exact parser로 검증하고, 로그인·active household 준비 후 authenticated target RPC가 recipient membership, uncancelled inbox item과 subject 일치를 다시 확인한 경우에만 Today의 안전한 목적지로 이동한다. 실패·stale·다른 household는 알림 센터로 fail closed한다. |
| WP05-04 / FR-NOTIF-006 / NFR-REL-01 | `(source_event_id, endpoint_id)`당 delivery identity를 하나만 만들고 lease/finalize를 멱등 처리한다. provider success receipt는 원문 대신 SHA-256 hash만 보존하며 retry는 최대 5회로 제한한다. permanent unregistered/invalid token은 exact fingerprint guard로 endpoint를 revoke한다. 고급 outage/backoff/alert drill은 WP05-05에 남긴다. |
| WP05-04 / NFR-SEC-01 / NFR-PRIV-01 | FCM data에는 contract version, delivery/inbox/household/occurrence/category 식별자만 포함한다. Android-visible title/body는 앱 resource localization key로 정하고 가족 이름·할 일 제목·사용자 표시정보를 server payload/receipt/log에 넣지 않는다. ciphertext/token은 provider worker memory 밖으로 노출하지 않는다. |
| WP05-04 / NFR-COMP-01 / D-002 / D-021 | Android Store MVP만 활성화한다. Firebase public client options는 optional all-or-none allowlist로 읽고 비구성·비Android에서는 unavailable adapter로 fail closed한다. iOS/APNs는 Android Beta 이후 별도 ADR 전까지 구현·주장하지 않는다. |

## Data and API Impact

- `app_private.notification_push_evaluations`: source event의 최신 상태와 현재 `native_push` preference를 durable inbox 생성 여부와 독립적으로 재평가한다. 따라서 `in_app=false/native_push=true`도 전송 후보가 될 수 있다.
- `app_private.notification_push_deliveries`: `(source_event_id, endpoint_id)` unique delivery, lease/attempt/state, stable provider result code, provider receipt SHA-256 hash, success/final timestamps를 content-free로 저장한다. inbox item은 존재할 때만 nullable reference로 연결한다.
- service-role-only APIs:
  - `claim_notification_push_deliveries(...)` — due source event × active Android endpoint를 최신 상태·preference·quiet hours로 다시 평가해 create/claim하고 ciphertext/fingerprint/key version과 최소 routing envelope를 worker에만 반환
  - `complete_notification_push_delivery(...)` — exact lease를 success/retry/permanent failure로 finalize하고 permanent invalid token을 fingerprint-guarded invalidate
- authenticated API:
  - `resolve_notification_push_target(...)` — current recipient, active membership, uncancelled inbox envelope와 household/occurrence exact match를 확인하고 safe target metadata만 반환
- Edge Function `notification-push-worker`:
  - scheduler-secret authenticated one-batch handler
  - versioned AES-GCM endpoint envelope open, Firebase service-account OAuth token exchange, FCM HTTP v1 send
  - Android localization keys와 minimal data payload, aggregate-only response/error
- Flutter:
  - pure push envelope/permission/tap coordinator contracts and strict target resolver
  - Firebase Messaging Android gateway, local notification presenter, optional public Firebase options composition
  - explicit pre-prompt UI, permission/settings state, foreground presentation dedupe, background/terminated tap continuation

## Dependency Gate

| Dependency | Pinned intent / platform | Gate |
|---|---|---|
| `firebase_core` | resolver-selected version compatible with Flutter 3.44.7; Android runtime options only | Firebase official initialization contract; BSD-3-Clause family; no Analytics; public client identifiers only |
| `firebase_messaging` | current compatible release (`16.5.0` observed 2026-08-08), Android-only composition | Android 13 permission, top-level `@pragma('vm:entry-point')` background handler, `onMessage`, `onMessageOpenedApp`, `getInitialMessage`; BSD-3-Clause |
| `flutter_local_notifications` | current compatible release (`22.2.0` observed 2026-08-08), Android foreground display only | Flutter >=3.38.1, compileSdk >=35, Java 17, core library desugaring; existing Flutter/Android toolchain satisfies baseline |

- Firebase/APNs server credential, private key, service role과 OAuth access token은 public config, Flutter state, logs, test fixtures 또는 evidence에 기록하지 않는다.
- APK permission allowlist에는 앱의 기존 `INTERNET`, biometric과 package-scoped receiver 외에 Android 13 `POST_NOTIFICATIONS`, FCM/local presentation에 필요한 `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `VIBRATE`, `com.google.android.c2dm.permission.RECEIVE`만 추가한다. 위치·연락처·광고 ID·광범위 storage permission은 추가하지 않는다.
- no Firebase Analytics/Crashlytics/App Check dependency를 추가하지 않는다. provider adapter rollback은 composition disable과 Edge scheduler disable로 가능해야 한다.

## Verification

- pgTAP: schema/check/index/FK/grant/RLS/security-definer/search-path, one-delivery-per-endpoint, current preference/membership/cancellation suppression, quiet-hour due gate, concurrent lease, exact finalize, stale lease/fingerprint rejection, receipt privacy, authenticated target isolation
- Edge: exact claim/finalize contracts, scheduler auth, ciphertext open only in memory, OAuth JWT/token exchange, FCM request exact keys/localization, permanent/transient mapping, non-reflection, bounded aggregate summary
- Flutter: exact envelope parser, no first-launch prompt, denied/authorized flow, token missing/rotation, foreground one-local-presentation, background/terminated/local taps, auth/household wait, target allow/deny/stale fallback, lifecycle purge/account switch, unavailable configuration
- Android: manifest permission/default channel, desugaring, generic en/ko resources, flavor/application ID and source provenance preservation
- clean reset, focused/full pgTAP, DB lint, repository JavaScript and Flutter regression, analyzer/formatter/config/secret/codegen/dependency/license/OSV/workflow/matrix/whitespace gates

## Security and Privacy

- provider worker만 mediated claim을 통해 sealed token envelope를 받는다. direct table access와 external response에는 token, ciphertext, fingerprint, provider body 또는 identity display data가 없다.
- foreground display와 background OS display 모두 generic localized copy만 사용한다. deep-link payload는 capability가 아니며 반드시 authenticated target RPC로 재인가한다.
- Android permission은 user gesture 뒤에만 요청하고 denied/unsupported는 endpoint 등록을 시도하지 않는다. durable inbox는 provider/permission과 독립적으로 유지한다.
- background handler는 UI/state mutation이나 30초 초과 작업을 하지 않고 exact envelope validation 외의 정확성을 맡지 않는다.

## Rollback

- `notification-push-worker` scheduler와 Firebase client public options를 비활성화하면 durable inbox와 기존 endpoint lifecycle은 계속 동작한다.
- production 전에는 migration, Edge, Flutter adapter/dependencies, Android manifest/resources와 tests/contracts를 함께 revert한다.
- production 후에는 applied migration을 수정하지 않는다. forward migration으로 claim execute를 revoke하고 pending/leased delivery를 stable rollback reason으로 종결하며, active endpoint는 필요 시 기존 `rollback_disabled` lifecycle로 revoke한다.

## Completion Boundary

- synthetic FCM provider와 fake mobile gateway로 DB/Edge/Flutter Android lifecycle 및 전체 회귀가 green이면 WP05-04를 `LOCAL IMPLEMENTED`로 기록한다.
- 실제 Firebase console registration, service-account secret, physical Android foreground/background/terminated send와 OEM matrix는 사용자 지시대로 대다수 기능 개발 뒤 마지막 Gate에서 수행한다.
- iOS/APNs는 D-021에 따라 Android Beta 이후 별도 ADR 없이는 범위에 포함하지 않는다.
