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

각 rule은 recipient, base schedule instant, 개인 lead time, quiet hours, dedupe, expiry를 계산한다. Calendar는 exact recipient의 고정 lead를 base에서 먼저 뺀 뒤 quiet hours를 적용하며, source payload는 개인 시간을 복제하지 않는다. preference 변경은 미평가 candidate만 재스케줄하고 평가된 이력은 동결한다.

Calendar는 기존 기본 lead 1개와 additional fixed lead 최대 2개를 지원한다. 각 source는 같은 occurrence/version/audience 안에서 private lead identity로 dedupe되고 exact 5-key content-free payload를 공유한다. occurrence/horizon capture는 current set을 모두 생성하며 설정 변경은 future-only source를 추가하고 pending resolution/push만 이동한다. 제거된 explicit source는 current preference 재검사에서 stale 처리하고 evaluated history는 보존한다. preference v1은 전체 집합, v2는 additional 값을 보존하며 v3만 전체 집합을 strict 편집한다.

Calendar Snooze는 이미 materialized된 caller-owned reminder를 새 explicit schedule source로 교체한다. 5·10·30분, 연속 최대 3회, occurrence base start 후 1시간 이내를 서버가 검사하고, original item version과 UUID command receipt로 response-loss를 멱등 처리한다. 새 source는 content-free이며 quiet hours·inbox·Android push worker를 재사용하고, 이후 lead preference 변경은 explicit Snooze 시각을 다시 계산하지 않는다.

## 9. Delivery

- inbox first
- push provider next
- email은 초대/보안/구독/삭제와 D-069에서 승인한 opted-in generic Chore/Calendar fallback 유형만 허용한다. category preference는 기본 OFF이며 inbox·push와 독립적이다.
- generic fallback은 confirmed Auth address를 service-only claim 동안만 사용한다. address-free queue에는 source/recipient/subject identity와 stable result code만 남기고 family content, email, provider body/raw error를 저장하지 않는다.
- email provider I/O 전에 lease-bound submission marker를 기록한다. `202`만 accepted, `429/500/502/503/504`만 최대 5회 bounded retry이며 marker 이후 network ambiguity는 terminal quarantine한다. optional provider receipt는 SHA-256만 보존한다.
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
- exact-recipient Calendar lead와 pending-only reschedule/frozen-history boundary
- Calendar primary-plus-two source identity, future-only add, removed-source stale suppression과 v1/v2/v3 compatibility
- Calendar Snooze count/window, optimistic replay, pre-due suppression, due inbox/push와 explicit schedule 보존
- email preference/channel independence, confirmed-address ephemeral boundary, quiet-hours/one-hour expiry, marker-before-I/O, explicit retry mapping, address/content-free persistence와 aggregate-only worker response
- app states foreground/background/terminated
- notification tap authz
- account/household switch purge
