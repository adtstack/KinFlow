# 08. 기술 아키텍처

- 상태: ACCEPTED
- 기준일: 2026-07-21
- 목적: Flutter 모바일 앱, 후속 Web Companion, Supabase 백엔드의 경계와 의존 방향을 고정한다.

## 1. 아키텍처 목표

KinFlow 아키텍처는 다음 품질을 우선한다.

1. 가족 간 데이터가 household 경계를 절대 넘지 않는다.
2. Android 구현은 플랫폼 SDK와 분리된 도메인 규칙을 사용해 후속 플랫폼 확장을 막지 않는다.
3. 모바일 Store MVP를 Web/Desktop보다 먼저 안정적으로 출시한다.
4. 클라이언트 SDK 교체가 도메인 규칙을 흔들지 않는다.
5. 반복 일정, 역할 변경, 결제처럼 고위험 mutation은 서버 transaction으로 처리한다.
6. 바이브코딩 에이전트가 작은 vertical slice 단위로 구현하고 검증할 수 있다.

## 2. 시스템 컨텍스트

```text
Flutter mobile app ─┐
Flutter Web companion ─┼─ HTTPS/WSS ─ Supabase platform
Public website ────────┘                 ├─ Auth
                                         ├─ PostgreSQL + RLS
                                         ├─ Edge Functions
                                         ├─ Storage
                                         └─ Realtime (선택적)

Apple App Store / Google Play ─ RevenueCat ─ webhook ─ entitlement worker
APNs / FCM ─ notification worker ─ notification inbox/device registrations
Sentry / analytics ─ privacy-filtered operational events
```

## 3. 클라이언트 의존 방향

```text
Presentation (Widget, Router, Provider)
                  ↓
Application (Use case, orchestration, state machine)
                  ↓
Domain (Entity, value object, policy, repository port)
                  ↑
Data/Infrastructure (Supabase, RevenueCat, Firebase, secure storage)
```

금지 규칙:

- `domain/`은 Flutter, Riverpod, Supabase, RevenueCat, Firebase, `dart:html`을 import하지 않는다.
- Widget은 Supabase client나 billing SDK를 직접 호출하지 않는다.
- DTO는 presentation으로 누출하지 않는다.
- Provider는 domain invariant를 새로 정의하지 않고 use case를 조정한다.
- 플랫폼별 구현은 interface/port 뒤에 둔다.

## 4. 주요 bounded context

| Context | 책임 | 주요 Aggregate |
|---|---|---|
| Identity | 로그인, 세션, 계정 상태 | UserAccount, Session |
| Household | 가구, 역할, 초대, 보호자 관리 프로필 | Household, Membership, Invite |
| Chores | 집안일 정의, 발생 회차, 완료·승인 | ChoreSeries, ChoreOccurrence |
| Calendar | 일정, 참석자, 반복·예외 | EventSeries, EventOccurrence |
| Today | 날짜 경계에 따른 통합 읽기 모델 | TodaySnapshot |
| Notifications | 알림 선호, inbox, device token, delivery | NotificationJob |
| Billing | 구매, 복원, household entitlement | BillingAccount, Entitlement |
| Privacy | 내보내기, 계정·가구 삭제 | DeletionRequest, ExportJob |

Context 간 쓰기는 가능한 한 명시적 command/RPC로 처리한다. Today는 다른 context의 source of truth가 아니라 read model이다.

## 5. 데이터 흐름 원칙

### 5.1 일반 조회

- RLS가 충분한 단순 조회는 Supabase query를 사용한다.
- 목록에는 stable pagination cursor와 deterministic order를 사용한다.
- 앱은 모든 family row에 household context를 명시한다.
- cache key는 최소 `userId + householdId + resource + query`를 포함한다.

### 5.2 고위험 mutation

다음은 RPC 또는 Edge Function transaction으로 처리한다.

- 초대 생성·수락·회수
- Owner 이전, 역할 변경, 구성원 제거
- Managed Child 대신 행동하기
- 반복 시리즈 수정과 occurrence 재생성
- 계정·가구 삭제와 내보내기
- billing household 연결과 entitlement 갱신
- idempotency가 필요한 외부 webhook 처리

### 5.3 이벤트와 작업 큐

DB transaction에서 domain event/outbox row를 기록하고 worker가 후속 작업을 수행한다.

```text
business transaction
  ├─ source row 변경
  └─ outbox event 기록
          ↓
worker claims row with lease
          ↓
external delivery
          ↓
succeeded / retry_at / dead_letter
```

외부 알림이나 webhook 성공을 DB transaction 안에서 기다리지 않는다.

## 6. 런타임과 환경

| 환경 | Flutter flavor | Bundle/Package | Supabase | Firebase | RevenueCat |
|---|---|---|---|---|---|
| local/dev | `dev` | 개발 전용 ID | local/dev | dev project | test project |
| staging | `staging` | staging ID | staging | staging project | sandbox/test |
| production | `prod` | production ID | production | production project | production |

환경 간 계정·token·database·analytics project를 공유하지 않는다. 공개 client configuration만 빌드에 포함한다. service role, webhook secret, signing secret은 CI secret 또는 server secret manager에만 둔다.

## 7. 모바일과 Web Companion의 차이

| Capability | Mobile Store MVP | Web Companion |
|---|---|---|
| Auth | Universal/App Links, secure token store | HTTPS redirect, browser session |
| Push | APNs/FCM | 후속 Web Push 또는 inbox/email fallback |
| Billing | Store purchase/restore | 처음에는 entitlement 조회; paid web는 별도 결정 |
| Offline | read cache, 제한된 safe outbox | stale 표시, broad persistent API cache 금지 |
| Background | OS가 허용하는 best-effort | foreground/session 기반 |
| Public SEO | 제공하지 않음 | 별도 Astro 사이트 |

## 8. Realtime 정책

Realtime은 사용자 가치가 명확한 화면에만 사용한다.

- Today와 household member 변경은 후보이다.
- subscription reconnect 후 전체 refetch를 수행한다.
- Realtime event는 권위 있는 mutation 응답을 대체하지 않는다.
- 동일 event 중복 수신을 허용하고 idempotent reducer를 사용한다.
- 앱 background에서는 불필요한 channel을 해제한다.

## 9. 버전 호환성

클라이언트는 다음 헤더/필드를 제공한다.

```text
X-KinFlow-Client-Version
X-KinFlow-Contract-Version
X-KinFlow-Platform
X-KinFlow-Idempotency-Key (mutation별)
```

서버는 `minimum_supported_client_version`과 contract range를 remote configuration에서 제공할 수 있다. 호환되지 않는 mutation은 명확한 update-required 오류로 차단하며, 읽기와 내보내기/삭제 접근은 가능한 범위에서 유지한다.

## 10. 실패 격리

- billing 장애가 chores/calendar 읽기를 막지 않는다.
- push 장애가 in-app inbox 생성을 막지 않는다.
- analytics 장애가 핵심 mutation을 실패시키지 않는다.
- Today read model 생성 실패 시 원본 chores/calendar 목록으로 fallback한다.
- server clock과 DB timestamp를 권위 기준으로 사용한다.

## 11. Architecture Gate

Phase 01 종료 전 다음 증거가 필요하다.

- dependency graph 검사에서 domain 금지 import 0
- dev/prod flavor 각각 boot smoke test
- Supabase local migration + RLS test 성공
- Android emulator/실기기 signed-in shell 실행
- crash/error reporting이 개인정보 필터 후 staging으로 수집
- generated code 재생성 후 diff 0
