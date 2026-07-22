# 23. Flutter UI와 플랫폼 구현 스펙

- 상태: ACCEPTED

## 1. App shell

- MaterialApp.router
- locale/theme/router/provider가 app shell에서 주입
- auth/bootstrap 상태를 route와 분리
- global error boundary와 recovery action
- staging/dev build에만 environment banner/debug panel

## 2. 디자인 시스템

Token:

- spacing, radius, elevation
- semantic color
- typography and text scale
- touch target
- motion duration/easing
- layout breakpoint

Material 3를 기반으로 하되 브랜드 의미를 token으로 정의한다. 색상 하나만으로 완료/지연/오류를 표현하지 않는다.

## 3. 핵심 화면

### Today

- household date와 timezone 표시
- chores와 events section
- assignee/member filter
- stale/offline banner
- optimistic completion은 server confirmation/rollback 명확화
- empty state에서 첫 chore/event 생성 유도

### Chores

- occurrence와 series 편집을 구분
- 완료/취소/승인 state
- 반복 규칙을 사람이 읽는 문장으로 표시
- assignee picker에서 household 경계 유지

### Calendar

- day/week/month 중 MVP 범위는 PRD 따름
- all-day와 timed event 구분
- timezone 표시/편집
- single occurrence vs whole series 선택
- accessible date/time input

### Family

- role/status/managed member 표시
- invite token 원문을 log/analytics에 남기지 않음
- Owner 전용 action 분리
- child mode 전환/종료가 항상 보임

### Subscription

- store에서 가져온 local price
- household 혜택과 자동 갱신 설명
- purchase pending server confirmation
- restore와 support path
- active/expired/billing issue 상태

## 4. Form

- client validation은 UX, server validation이 권위
- unsaved changes 보호
- keyboard action과 focus 이동
- server field/global error 매핑
- double submit 방지와 idempotency
- date/timezone input의 원래 의도 보존

## 5. Permission flow

알림 권한은 첫 실행 즉시 요구하지 않는다.

1. 가치 설명 pre-prompt
2. 사용자가 reminder 설정 또는 관련 action 수행
3. OS permission 요청
4. denied 상태와 settings deep link
5. inbox/email fallback

캘린더/연락처 권한은 MVP에 필요 없으면 요청하지 않는다.

## 6. Deep link

- Universal Links/App Links 우선
- custom scheme은 개발/보조 fallback
- auth callback와 invite link host/path allowlist
- token은 화면/analytics에 노출하지 않음
- cold/warm/background state 모두 테스트
- 로그인 필요 시 목적 route를 안전하게 임시 보존

## 7. Push 처리

- background handler는 top-level entry point 요구사항 준수
- payload parse를 pure function으로 테스트
- notification tap은 resource refetch와 authz 재검증
- foreground에서 중복 system/local notification 방지
- badge/inbox unread count 동기화

## 8. 접근성

- Semantics label/value/hint
- screen reader focus order
- minimum touch target
- text scaling 200%
- contrast와 non-color cue
- reduced motion
- landscape/split screen
- keyboard navigation for tablet/Web

접근성 문제를 Beta 후 polish로 미루지 않는다.

## 9. Localization

- ARB + gen_l10n
- 영어 source와 한국어 번역
- pseudo locale
- plural/gender/number/date formatting
- 문자열 연결 금지
- 긴 독일어/프랑스어와 RTL 구조 사전 테스트
- server error code를 locale key로 매핑

## 10. 성능

- 긴 목록 lazy build
- rebuild scope 최소화
- image/avatar cache 제한
- startup에 불필요한 SDK init 지연
- large household seed로 frame/build profile
- jank 측정은 release/profile build 실제 기기

## 11. 플랫폼 차이

| 기능 | iOS | Android | Web |
|---|---|---|---|
| Back | navigation convention | system back/predictive back | browser history |
| Billing | App Store | Play Billing | 초기 조회만 |
| Push | APNs via FCM | FCM | 후속 |
| Secure store | Keychain | Keystore-backed | browser strategy |
| Update | App Store | Play Store | atomic deploy |

## 12. 화면 테스트 식별자

E2E에 필요한 stable semantic/test keys만 제공한다. 구현 class name/텍스트에 과도하게 의존하지 않는다. test key가 사용자 개인정보를 포함하지 않는다.
