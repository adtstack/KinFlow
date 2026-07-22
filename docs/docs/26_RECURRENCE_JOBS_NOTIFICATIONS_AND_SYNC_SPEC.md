# 26. 반복, 작업 큐, 알림, 동기화 구현 스펙

- 상태: ACCEPTED

## 1. 시간 type

- Instant: UTC timestamp
- Timezone: IANA ID
- LocalDate: 달력 날짜
- LocalTime: 사용자가 의도한 벽시계 시간
- ZonedIntent: LocalDate/Time + timezone + DST resolution policy
- AllDayRange: date-based exclusive end

Dart `DateTime`만으로 모든 의미를 표현하지 않는다. timezone library 선택은 Phase 04 dependency Gate에서 확정한다.

## 2. 반복 모델

```text
Series: identity/owner/status
Revision: rule, local intent, timezone, effective range
Occurrence: materialized scheduled instance and state
Exception: cancel/override/single edit
```

RRULE을 저장할 수 있지만 RRULE 문자열만 source of truth로 삼지 않고 지원 subset과 validation을 명시한다.

## 3. 수정 범위

MVP:

- 이 회차만 수정
- 전체 시리즈의 향후 회차 수정
- 이 회차 취소
- 시리즈 종료

“이후 모든 회차”가 구현되면 revision effective boundary를 사용한다. 완료된 과거 occurrence는 보존한다.

## 4. Materialization horizon

- Today/알림 요구를 충족하는 과거/미래 window
- worker가 주기적으로 horizon 확장
- 화면 요청 시 bounded on-demand 보완 가능
- 동일 occurrence unique key
- job retry idempotent
- time library/version 변경 시 migration 검토

## 5. DST 정책

사용자에게 예측 가능한 정책을 제품 결정으로 문서화한다.

- 존재하지 않는 local time: 다음 유효 시각으로 이동 또는 생성 차단
- 중복 local time: earlier/later offset 선택
- all-day: timezone instant로 강제 변환하지 않음
- 여행: series timezone 유지, 표시만 device/user timezone 선택

모든 정책은 `TIME_RECURRENCE_TEST_MATRIX.csv` fixture를 갖는다.

## 6. Chore completion

- occurrence state와 expected version
- actor/authenticated user 기록
- optional approval flow
- duplicate tap idempotent
- offline outbox Gate 시 TTL과 membership 재검증
- recurring series 정의와 완료 history 분리

## 7. Job queue

상태:

```text
pending → leased → succeeded
             ├→ pending(retry_at)
             └→ dead_letter
```

필드:

- type, payload/version
- dedupe key
- attempt/max_attempt
- retry_at
- lease_owner/lease_until
- last_error_code
- created/completed timestamps

## 8. Notification rule

- event/occurrence reminder
- chore due/overdue
- assignment/mention-like event
- invite
- subscription lifecycle
- privacy/security event

각 rule은 recipient, schedule instant, quiet hours, dedupe, expiry를 계산한다.

## 9. Delivery

- inbox first
- push provider next
- email은 초대/보안/구독/삭제 등 승인된 유형
- stale notification은 provider 제출 생략 가능
- provider receipt와 invalid token 정리
- 내용 최소화, 잠금 화면 privacy setting

## 10. Client sync

- app resume와 push tap에서 targeted refetch
- optimistic UI는 rollback snapshot 보유
- version conflict는 latest와 user decision
- Realtime은 invalidation 보조
- offline 상태를 명시하고 high-risk mutation 비활성

## 11. Background 제한

iOS/Android background execution을 정확한 스케줄러로 간주하지 않는다. 중요한 due notification은 서버 worker에서 생성한다. client background task는 token refresh, local cache maintenance 같은 opportunistic 작업만 수행한다.

## 12. 검증

- clock-controlled deterministic tests
- DST/month-end/leap-year
- worker crash/lease expiry
- duplicate/out-of-order domain event
- provider outage
- quiet hours boundary
- app states foreground/background/terminated
- notification tap authz
- account/household switch purge
