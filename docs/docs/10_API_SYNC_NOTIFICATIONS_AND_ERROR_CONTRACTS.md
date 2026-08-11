# 10. API, 동기화, 알림, 오류 계약

- 상태: ACCEPTED
- Source of Truth: `contracts/openapi-edge.yaml`, `contracts/error-catalog.yaml`, `contracts/domain-events.yaml`

## 1. API 스타일

- 단순 RLS-safe read: Supabase client query
- transaction command: PostgreSQL RPC
- 외부 provider/webhook, 장기 작업, admin orchestration: Edge Function
- 모든 command는 stable error code와 request ID를 반환한다.
- 외부로 노출되는 Edge Function은 OpenAPI 계약을 갖는다.

## 2. 공통 요청 메타데이터

| 항목 | 용도 |
|---|---|
| Authorization | Supabase access token |
| X-KinFlow-Request-Id | client/server correlation |
| X-KinFlow-Idempotency-Key | 재시도 가능한 command dedupe |
| X-KinFlow-Client-Version | 최소 지원 버전 판단 |
| X-KinFlow-Contract-Version | API 호환성 판단 |
| X-KinFlow-Platform | ios/android/web/desktop |
| X-KinFlow-Timezone | 표시 힌트; 저장 권위는 별도 payload |

## 3. 응답 envelope

```json
{
  "data": {},
  "meta": {
    "requestId": "uuid",
    "serverTime": "2026-07-21T00:00:00Z",
    "contractVersion": "1.0"
  }
}
```

오류:

```json
{
  "error": {
    "code": "CONFLICT_VERSION",
    "messageKey": "errors.conflictVersion",
    "retryable": false,
    "details": {},
    "requestId": "uuid"
  }
}
```

사용자용 문자열은 서버 message를 그대로 표시하지 않고 `messageKey`를 locale resource로 변환한다.

## 4. Idempotency

대상:

- 초대 수락
- 완료 처리/취소
- 반복 시리즈 변경
- 결제 restore/link
- deletion/export 요청
- webhook 처리
- notification job 생성

같은 사용자·operation·idempotency key가 재전송되면 같은 결과를 반환한다. payload hash가 다르면 `IDEMPOTENCY_KEY_REUSED`를 반환한다. key TTL과 response retention을 operation별로 정의한다.

## 5. 동기화 모델

MVP는 완전한 offline-first가 아니다.

### 읽기

- 최근 household snapshot을 memory 또는 제한된 local DB에 보관 가능
- cache row는 userId/householdId/contractVersion으로 namespace
- stale timestamp를 UI에 표시
- logout/account/household switch 시 purge

### 쓰기

- 역할, 초대, 결제, 삭제, recurrence definition은 online-only
- chore completion outbox는 별도 Gate 통과 후에만 허용
- outbox item은 auth subject, household, expected version, TTL, idempotency key를 포함
- 재인증 또는 membership 변경 시 자동 재생하지 않는다.

## 6. Realtime 재동기화

1. initial query
2. realtime subscription 연결
3. event 수신 시 cache invalidation 또는 deterministic patch
4. reconnect 후 cursor/delta가 없다면 full refetch
5. app resume 시 critical screen refetch

순서가 뒤바뀐 event와 중복 event를 허용한다.

## 7. 알림 파이프라인

```text
Domain event/outbox
  → notification rule evaluator
  → notification job (dedupe key)
  → recipient preference/lead time/quiet hours
  → inbox row 생성
  → platform delivery attempt
  → provider receipt 처리
```

in-app inbox 생성이 push 또는 email provider 성공에 의존하지 않는다. category별 email fallback은 기본 OFF이고 inbox·push와 독립적으로 선택된다. confirmed Auth address는 service-only claim에서 provider 호출 직전에만 사용하며 queue·audit·log에는 저장하지 않는다.

## 8. 모바일 알림 구현

- FCM을 Flutter 공통 entry로 사용하고 iOS는 APNs capability를 구성한다.
- foreground/background/terminated 상태를 각각 테스트한다.
- token rotation과 invalid token 제거를 구현한다.
- notification payload에는 최소 식별자만 포함하고 민감한 가족 내용을 넣지 않는다.
- tap 시 deep link route를 서버 권한 재검증 후 연다.
- local notification은 사용자 기기 편의이며 server due job의 권위를 대체하지 않는다.
- Calendar Snooze는 현재 caller-owned inbox item에 대한 versioned/idempotent server command다. 원본 inbox와 pending push를 원자적으로 supersede하고 새 content-free source event를 기존 server worker에 넣으며 client local alarm을 schedule authority로 사용하지 않는다.
- 허용값은 5·10·30분, 연속 최대 3회, occurrence base start 후 1시간 이내다. v1 inbox read는 유지하고 v2만 현재 허용 가능한 bounded metadata를 추가한다.
- Calendar preference는 기본 알림 1개와 추가 최대 2개의 distinct fixed lead를 가진다. v1은 전체 집합을 보존하고 v2는 기본만 바꾸며, exact 14-key v3만 전체 집합을 편집한다.
- 각 선택 시간은 동일한 exact content-free source payload와 private lead identity로 기존 server worker를 독립 통과한다. 설정 시점에 이미 지난 시간은 소급 발송하지 않는다.
- configured email fallback은 family content·resource ID·deep link가 없는 fixed generic EN/KO text를 한 명의 confirmed account address로만 보낸다. provider SDK, HTML, attachment와 custom argument는 사용하지 않는다.
- email worker는 exact empty POST와 dedicated Bearer만 허용하고 aggregate count만 반환한다. durable submission marker를 provider I/O 전에 기록하며, marker 이후 결과가 불명확하면 terminal ambiguity로 격리해 자동 재발송하지 않는다.

## 9. Quiet hours와 시간대

- household reminder 기준과 사용자 quiet hours를 분리한다.
- Calendar는 source에 timed start 또는 all-day household-local 09:00 base instant를 보존하고, exact 수신자의 고정 lead를 뺀 뒤 quiet hours를 적용한다.
- Calendar의 기본 및 추가 각 lead에서 quiet hours를 독립 적용한다. preference 변경은 아직 평가되지 않은 개인 reminder만 생성·재스케줄하고 제거된 source는 latest-state에서 stale 처리하며 이미 inbox 또는 terminal push 평가된 이력은 동결한다.
- email은 동일한 recipient-local quiet-hours 결과와 source schedule 뒤 최대 1시간 usefulness window를 재사용한다. window를 넘긴 claim 또는 retry는 provider 제출 없이 만료한다.
- 일정 원래 timezone과 수신자 timezone을 구분한다.
- DST 전환 시 중복/누락이 없도록 occurrence instant를 사용한다.
- 발송 지연이 허용 범위를 넘으면 inbox에는 남기고 stale push를 생략할 수 있다.

## 10. 오류 분류

| 분류 | 예시 | Client 정책 |
|---|---|---|
| Validation | INVALID_INPUT | field error, 자동 재시도 금지 |
| Auth | SESSION_EXPIRED | session refresh 또는 로그인 |
| Authorization | HOUSEHOLD_ACCESS_DENIED | cache purge + 안전 화면 |
| Conflict | CONFLICT_VERSION | 최신 데이터 표시, 사용자 재결정 |
| Rate limit | RATE_LIMITED | Retry-After 준수 |
| Dependency | PROVIDER_UNAVAILABLE | bounded retry, 핵심 데이터 유지 |
| Invariant | LAST_OWNER_REQUIRED | 설명 후 허용 경로 제공 |
| Update | CLIENT_UPDATE_REQUIRED | store update 안내 |

## 11. 재시도 정책

- 네트워크·5xx·provider transient만 exponential backoff + jitter
- 4xx validation/authz는 자동 재시도하지 않는다.
- mutation retry에는 idempotency key 필수
- email provider는 completed HTTP 중 `429/500/502/503/504`만 `1m/5m/30m/2h`로 제한 재시도한다. `202`는 provider accepted submission이며, 그 밖의 completed response와 marker 이후 network ambiguity는 terminal이다.
- background retry 횟수와 TTL을 제한한다.
- 사용자 행동을 무한 spinner로 가리지 않는다.

## 12. Contract test

- OpenAPI schema positive/negative test
- stable error catalog coverage
- idempotency replay/payload mismatch
- auth/household injection
- app old/new contract compatibility
- notification duplicate/out-of-order receipt
- provider timeout and dead letter
- deep link from stale/deleted resource
