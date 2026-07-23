# 20. Flutter 플랫폼·클라이언트 아키텍처

- 상태: ACCEPTED
- Tier 1: Android
- Tier 2: Flutter Web Companion
- Deferred: iOS/iPadOS, Flutter Windows/macOS/Linux

## 1. Native-first 원칙

KinFlow의 첫 핵심 채널은 Google Play다. iOS/iPadOS는 Android Beta review 뒤 별도 ADR로 재승인한다. Web은 설치형 PWA 획득 채널이 아니라 PC에서 가족 일정과 집안일을 관리하는 companion이다. Flutter가 지원하는 플랫폼 수와 실제 출시 플랫폼 수를 혼동하지 않는다.

## 2. 지원 기준

| 플랫폼 | Store MVP | 최소 기준 | 검증 |
|---|---:|---|---|
| iPhone/iPad | 아니오, 후속 검토 | 재도입 ADR에서 결정 | Android Beta review 이후 |
| Android phone/tablet | 예 | API 24+ runtime, target API 36 | emulator + 실제 저사양/최신 기기 |
| Web | 후속 | 최신 주요 browser | Playwright + 수동 접근성 |
| Windows/macOS/Linux | 아니오 | 수요 Gate 후 결정 | plugin audit/PoC 이후 |

Flutter 공식 지원 범위보다 제품 최소 버전을 높이는 것은 허용하며, 낮추려면 별도 compatibility test가 필요하다.

## 3. 앱 시작 구조

```text
main_dev.dart
main_prod.dart
      ↓
bootstrap(AppEnvironment)
      ├─ WidgetsFlutterBinding
      ├─ logging/Sentry privacy filter
      ├─ Firebase initialization
      ├─ Supabase initialization
      ├─ RevenueCat initialization after auth identity policy
      ├─ ProviderScope overrides
      └─ runApp(KinFlowApp)
```

초기화 실패를 하나의 blank screen으로 만들지 않는다. 필수/선택 의존성을 구분하고 recovery UI를 제공한다.

## 4. Capability port

```dart
abstract interface class NotificationService { ... }
abstract interface class BillingService { ... }
abstract interface class SecureStorage { ... }
abstract interface class DeepLinkSource { ... }
abstract interface class BackgroundScheduler { ... }
abstract interface class ConnectivityMonitor { ... }
abstract interface class AnalyticsSink { ... }
abstract interface class ParentalGate { ... }
```

플랫폼 구현은 `infrastructure/platform/`에 둔다. conditional import는 최소화하고 capability registry가 지원 여부를 노출한다.

## 5. Navigation

`go_router`를 사용한다.

주요 route:

```text
/splash
/auth/sign-in
/auth/callback
/onboarding/household
/invite/:token
/today
/chores
/chores/:occurrenceId
/calendar
/calendar/:occurrenceId
/family
/settings
/settings/subscription
/settings/privacy
```

규칙:

- auth redirect loop 방지
- invite와 auth callback cold start 처리
- deep link target을 열기 전 membership/RLS 재검증
- child mode에서 금지 route redirect
- 삭제된 resource는 안전한 not-found 상태
- navigator key를 전역 mutation escape hatch로 사용하지 않는다.

## 6. Riverpod 상태 소유권

- session: auth feature의 single provider
- active household: household feature의 single provider
- server collection: repository query + async notifier/cache
- form draft: screen-local state
- transient UI: widget/local provider
- entitlement: server snapshot provider

동일 데이터를 여러 provider에서 복제하지 않는다. provider dependency cycle을 CI architecture test로 검토한다.

## 7. Adaptive layout

폭 고정 기기 이름이 아니라 available space와 입력 capability를 사용한다.

| Size class | 예시 UI |
|---|---|
| compact | bottom NavigationBar, single pane, modal/full-screen form |
| medium | NavigationRail 또는 wider navigation, optional detail pane |
| expanded | persistent rail/sidebar, master-detail, keyboard shortcuts |

- 화면 회전과 split view에 반응한다.
- `MediaQuery.textScaler` 큰 글꼴에서도 핵심 action을 숨기지 않는다.
- hover가 있다고 touch가 없다고 가정하지 않는다.
- Cupertino adaptation은 interaction convention에 선택적으로 사용한다.

## 8. 앱 생명주기

- resume: session/active household/critical screen refresh
- inactive/background: sensitive acting mode timeout, analytics flush, unsafe mutation 금지
- terminated push tap: bootstrap 후 route replay
- memory pressure: non-critical cache release
- app upgrade: local schema migration과 cache contract check

## 9. Local persistence

초기 선택은 secure key-value + 제한된 query cache다. local SQL DB 도입은 offline value와 migration cost가 확인된 후 ADR로 결정한다.

- token/parental secret: secure storage
- preferences: platform preferences
- family data cache: encrypted 또는 최소화된 local store, namespace 필수
- outbox: 별도 Gate, TTL/idempotency/auth binding

## 10. Web Companion

- 동일 Flutter domain/application 코드를 가능한 범위에서 공유
- public marketing/legal site와 분리
- browser secure session과 cache purge
- Web Push/paid purchase/offline 설치는 초기 필수 아님
- SEO가 필요한 화면은 Astro site에서 제공
- browser back/refresh/deep link를 정상적인 navigation으로 처리

## 11. Desktop 확장 Gate

다음 데이터가 있어야 PoC를 시작한다.

- Web 사용자 중 desktop active 비중
- native notification/system tray 요구
- offline desktop 업무
- wall display/kiosk 수요
- plugin의 Windows/macOS/Linux support
- 별도 signing/store/update 운영 비용

Gate 전에는 desktop folder가 존재해도 release support를 약속하지 않는다.
