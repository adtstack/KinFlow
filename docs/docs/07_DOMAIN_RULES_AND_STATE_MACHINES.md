# 07. 도메인 규칙과 상태 머신

## 1. 핵심 불변조건

### 가구

- 한 가구에는 정확히 한 명의 Owner가 있다.
- Owner는 활성·인증된 성인 member여야 한다.
- 가구 생성과 Owner membership 생성은 atomic하다.
- 마지막 Owner는 삭제·탈퇴·강등될 수 없다.
- 모든 가구 종속 참조는 같은 `household_id`에 속해야 한다.

### 구성원

- 성인 member는 `user_id`를 가질 수 있고 Managed Child는 가져서는 안 된다.
- 동일 user가 동일 household에 중복 active membership을 가질 수 없다.
- Store MVP에서 한 user의 active household는 최대 하나다.
- 제거된 member의 과거 활동은 actor snapshot 또는 anonymized member ID로 보존한다.

### 자녀/보호자

- Managed Child는 최소 한 명의 active adult guardian을 가진다.
- guardian과 child는 같은 household여야 한다.
- child mode action은 authenticated adult session과 acting child 모두를 요구한다.
- child는 role, invitation, billing, privacy, export/delete mutation을 실행할 수 없다.

### 구독

- 한 활성 purchase owner는 기본적으로 한 paid household만 가진다.
- 한 household의 effective plan은 유효한 server entitlement record로 계산한다.
- 클라이언트 SDK 상태는 힌트이며 권한의 최종 근거가 아니다.
- 동일 provider event는 한 번만 효과를 발생시킨다.

## 2. 역할 권한 매트릭스

| Action | Owner | Admin | Member | Managed Child |
|---|:---:|:---:|:---:|:---:|
| 가구 보기 | ✓ | ✓ | ✓ | 제한 |
| 가구 이름/시간대 수정 | ✓ | ✓ | — | — |
| 초대 생성/회수 | ✓ | ✓ | — | — |
| 역할 변경 | ✓ | 제한 | — | — |
| Owner 이전 | ✓ | — | — | — |
| 구성원 제거 | ✓ | ✓* | — | — |
| 가구 삭제 | ✓ | — | — | — |
| Managed Child 생성/수정 | ✓ | ✓ | — | — |
| 집안일 생성 | ✓ | ✓ | ✓ | — |
| 모든 집안일 수정/삭제 | ✓ | ✓ | 제한 | — |
| 자기 배정 완료 | ✓ | ✓ | ✓ | ✓ |
| 자녀 완료 승인 | guardian | guardian | guardian만 | — |
| 일정 생성 | ✓ | ✓ | ✓ | — |
| 구독 구매/가구 연결 | ✓/성인 | 성인** | 성인** | — |
| export/계정 삭제 | 자기 계정 | 자기 계정 | 자기 계정 | 보호자 |

`*` Admin은 Owner나 자신보다 높은 권한을 제거할 수 없다.  
`**` 실제 정책은 billing household 선택과 Owner 승인 Gate에 따른다.

## 3. Membership 상태

```text
invited → active → left
             ├── removed
             └── suspended (운영/보안 예외)
```

- `invited`는 membership이 아니라 invitation으로 구현하는 것을 권장한다.
- `removed/left` 이후 access token이 남아 있어도 RLS가 즉시 접근을 거부한다.
- 재가입은 새 membership 또는 명시적 복구 정책을 사용하며 과거 role을 자동 복원하지 않는다.

## 4. 초대 상태

```text
created → opened → accepted
   ├── expired
   ├── revoked
   └── exhausted
```

규칙:

- 원문 token은 생성 응답에서 한 번만 제공하고 DB에는 hash만 저장한다.
- acceptance는 token lock/검증/membership 생성/use_count 증가를 transaction으로 수행한다.
- 동일 사용자의 재시도는 같은 결과를 반환하는 멱등성을 가진다.
- outsider에게 가구 존재·구성원 이메일을 과도하게 노출하지 않는다.

## 5. Chore occurrence 상태

```text
open ───────────────► completed ─────► reopened
 │                         │
 │ approval_required       │ adult undo
 ▼                         ▼
awaiting_approval ─► approved ───────► reopened
        └──────────► rejected ───────► open
```

### 전이 규칙

- `open→completed`: 담당 성인 또는 권한 있는 관리자.
- `open→awaiting_approval`: Managed Child가 approval-required item 완료.
- `awaiting_approval→approved/rejected`: 연결 guardian 또는 권한 있는 성인.
- 모든 전이는 version/updated_at 기반 stale-write 방지와 idempotency key를 사용한다.
- 완료 이력은 series 수정으로 삭제하지 않는다.

## 6. 일정 상태

- 일정 series는 `active`, `cancelled`, `archived` 상태를 가진다.
- occurrence는 generated 기본값과 exception overlay로 계산한다.
- 한 회차 취소는 series 삭제가 아니라 exception이다.
- 전체 series 삭제는 미래 occurrence를 취소하되 과거 감사/알림 기록 보관 정책을 따른다.

## 7. 반복 시간 의미

### Timed event

저장 요소:

- recurrence timezone: IANA zone
- local start time/date pattern
- duration 또는 local end rule
- canonical UTC instant per occurrence

예: “매주 월요일 오전 8시 서울”은 DST가 있는 지역으로 이동해도 원래 recurrence timezone의 오전 8시 기준인지, household timezone을 따라갈지 명시한다. 기본은 **series 생성 시 timezone에 고정**이다.

### All-day

- `start_date` 포함, `end_date_exclusive` 제외 규칙
- UTC 자정으로 변환해 저장하지 않는다.
- 사용자가 다른 시간대로 여행해도 날짜가 바뀌지 않는다.

### 월간

“매월 31일” 기본 정책:

- 31일이 없는 달은 그 달을 skip한다.
- “마지막 날”은 별도 규칙이다.
- 임의로 30일/28일로 당기지 않는다.

### Series 수정

- 이번 회차: exception만 생성/수정
- 전체 시리즈: 과거 완료/발생 이력은 유지, 변경 시점 이후 미래 회차 재계산
- 이번 이후: Store MVP 제외

## 8. Materialization

- 가까운 과거 일부와 미래 horizon을 occurrence table에 생성한다.
- job 재실행은 `(series_id, recurrence_id)` unique key로 중복을 막는다.
- series 변경 시 미래 미완료 occurrence를 안전하게 invalidate/rebuild한다.
- notification intent는 occurrence가 확정된 뒤 생성한다.
- horizon 끝에 다가오기 전에 background job이 연장한다.

## 9. 구독 상태 머신

```text
none → trialing/active → grace/billing_issue → active
                  ├── cancelled_but_active → expired
                  ├── refunded/revoked → inactive
                  └── transferred → source inactive / destination reconciled
```

`cancelled`는 즉시 만료가 아니라 현재 기간 종료일까지 active일 수 있다. Provider event 순서가 뒤바뀔 수 있으므로 event timestamp만으로 단순 덮어쓰지 않고 provider 상태를 재조회할 수 있어야 한다.

### Household entitlement 상태

- `free`
- `plus_active`
- `plus_grace`
- `plus_expired_over_limit`
- `plus_suspended`(fraud/support/manual)

effective plan 계산에는 provider entitlement, product mapping, environment, expiration, manual override의 우선순위를 명시한다.

## 10. 삭제 상태 머신

```text
requested → cooling_off(optional) → processing → completed
                                  └→ blocked_by_retention → completed_later
requested → cancelled (허용 기간 내)
processing → failed_retryable / manual_review
```

- 요청 즉시 새 세션 발급을 막거나 위험 action을 제한한다.
- 완료 시 auth token, refresh token, device token, invite token을 revoke한다.
- 세금·결제·보안상 보관해야 하는 데이터는 목적·기간·접근을 분리하고 앱 데이터와 unlink한다.
- 가구 삭제와 사용자 삭제는 서로 다른 workflow다.

## 11. 동시성·멱등성

- 생성 mutation은 client-generated id 또는 idempotency key를 지원한다.
- update에는 version 또는 `updated_at` precondition을 사용한다.
- 완료 버튼 연타, webhook duplicate, job retry가 중복 side effect를 만들지 않는다.
- conflict 시 자동 last-write-wins로 숨기지 않고 사용자에게 최신 상태를 보여준다.

## 12. 감사 이벤트

민감 action:

- role/owner 변경
- invite 생성·회수·수락
- managed child 생성·guardian 변경·child action
- subscription household link/transfer/manual override
- export/delete 요청과 완료
- notification consent/token 변경

감사 레코드는 actor user, acting member, household, action, target type/id, request/incident ID, timestamp, 결과를 가지며 제목·설명 등 콘텐츠는 넣지 않는다.

## 13. 플랫폼 불변조건

1. `platform`은 권한 근거가 아니다. 같은 인증자·가구·역할은 모바일과 웹에서 같은 서버 권한을 가진다.
2. capability availability와 product entitlement를 구분한다. 예를 들어 Web Push 미지원과 Plus 미가입은 다른 상태다.
3. occurrence ID, due date, all-day date, timezone 의미는 모든 클라이언트에서 동일하다.
4. client-local completion은 서버 version/idempotency 검증 전 확정 상태가 아니다.
5. 알림 intent는 provider 독립이고 delivery endpoint만 플랫폼별이다.
6. 구매 provider는 entitlement의 source가 아니라 검증 이벤트 source다. 실제 기능 권한은 서버 household entitlement다.
7. logout, auth user 변경, household 제거는 모든 플랫폼에서 사용자 범위 cache와 pending mutation을 폐기한다.
8. unsupported capability 전이는 사용자에게 보이는 상태로 모델링한다.
9. 모바일 앱 또는 Web Companion의 contract version이 서버 최소 호환 범위를 벗어나면 mutation을 안전하게 차단하고 업데이트 또는 reload를 안내한다.
10. 플랫폼별 presentation 차이가 audit actor, domain event, role transition을 바꾸지 않는다.

## 17. 클라이언트 런타임 독립 규칙

도메인 상태 전이는 Dart sealed type 또는 pure function으로 표현하되 Flutter Widget, Riverpod Provider, Supabase DTO와 독립적이어야 한다. 같은 invariant를 Edge Function과 DB constraint/RLS가 다시 보호한다. 클라이언트 domain test는 사용자 편의를 검증하며 서버 권한 검증을 대체하지 않는다.
