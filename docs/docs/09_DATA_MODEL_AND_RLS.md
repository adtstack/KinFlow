# 09. 데이터 모델과 Row Level Security

- 상태: ACCEPTED
- Source of Truth: `contracts/database-schema.sql`, `contracts/rls-contract.sql`

## 1. 핵심 원칙

1. 가구 소유 데이터는 모두 `household_id`를 가진다.
2. UUID를 안다고 접근할 수 없어야 한다.
3. UI에서 버튼을 숨기는 것은 권한 통제가 아니다.
4. `USING`과 `WITH CHECK`를 모두 검증한다.
5. 다른 household row를 연결하는 foreign key를 허용하지 않는다.
6. Owner lifecycle과 billing lifecycle은 일반 CRUD가 아니다.
7. service role은 최소 worker/administrative path에서만 사용한다.

## 2. 주요 테이블

| 영역 | 테이블 | 핵심 컬럼 |
|---|---|---|
| Identity | `profiles` | user_id, locale, timezone, deletion_state |
| Household | `households` | id, name, timezone, owner_membership_id, plan_state |
| Membership | `household_memberships` | household_id, user_id/profile_id, role, status |
| Child | `managed_members` | household_id, display_name, guardian_membership_id, status |
| Invite | `household_invites` | token_hash, short_code_hash, expires_at, max_uses, revoked_at |
| Chores | `chore_series`, `chore_revisions`, `chore_occurrences` | schedule, assignee, state, due_at |
| Calendar | `event_series`, `event_revisions`, `event_occurrences`, `event_participants` | local intent, timezone, start/end |
| Notifications | `notification_jobs`, `notification_deliveries`, `device_registrations`, `notification_inbox` | dedupe_key, status, provider |
| Billing | `billing_customers`, `store_transactions`, `household_entitlements`, `billing_events` | provider identity, valid_until |
| Privacy | `export_requests`, `deletion_requests`, `audit_events` | state, scope, actor, retention |
| Reliability | `idempotency_keys`, `outbox_events`, `worker_leases` | operation, response_hash, retry_at |

## 3. Household 관계 무결성

단순 `id` foreign key 대신 다음 패턴 중 하나를 사용한다.

```sql
UNIQUE (household_id, id)
FOREIGN KEY (household_id, assignee_member_id)
  REFERENCES household_memberships (household_id, id)
```

Managed member, event participant, chore assignee, notification recipient가 모두 같은 household인지 DB가 검증해야 한다. PostgreSQL 제약만으로 표현하기 어려운 경우 최소 범위의 trigger를 사용하고 pgTAP으로 검증한다.

## 4. 역할 모델

| 역할 | 기본 권한 |
|---|---|
| Owner | 가구 삭제, Owner 이전, billing household 지정, 모든 관리 |
| Admin | 초대·구성원·대부분 콘텐츠 관리, Owner 전용 작업 제외 |
| Member | 허용된 집안일·일정 생성/수정, 자신의 완료·응답 |
| Managed Child | 독립 auth identity 없음; guardian-gated acting context에서 제한 작업 |

Store MVP에 Guest 역할은 없다.

## 5. RLS helper 규칙

Helper function은 다음 특성을 갖는다.

- 안정적인 이름과 명시적 schema
- 필요 시 `security definer` + 빈 `search_path`
- 호출자 입력만으로 권한을 결정하지 않음
- auth.uid()와 active membership을 서버에서 조회
- billing entitlement와 role helper를 분리
- 함수 단위 권한과 회귀 테스트

예시 개념:

```sql
is_active_household_member(household_id uuid)
has_household_role(household_id uuid, roles text[])
can_act_as_managed_member(household_id uuid, managed_member_id uuid)
household_has_entitlement(household_id uuid, entitlement_key text)
```

## 6. Managed Child acting context

클라이언트의 `acting_member_id`는 힌트일 뿐이다. 서버는 다음을 확인한다.

1. 인증된 성인이 해당 household의 active member인지
2. managed member가 같은 household인지
3. guardian relation 또는 허용 역할인지
4. 요청한 action이 managed mode에서 허용되는지
5. parental gate가 필요한 action인지

감사 기록은 `authenticated_user_id`, `actor_membership_id`, `acting_managed_member_id`, `request_id`를 함께 보존한다.

## 7. 삭제와 참조

계정 삭제가 공동 가족 데이터를 무조건 cascade 삭제하지 않는다.

- 작성자 표시는 tombstone/anonymize 가능
- 공동 일정·집안일은 household 정책에 따라 유지
- 마지막 Owner는 이전 또는 household 삭제를 명시적으로 선택
- 법적 보존 대상 billing record는 제한된 별도 scope로 유지
- 모든 token, device registration, cache scope, invite는 폐기

## 8. 낙관적 동시성

수정 가능한 핵심 row에는 `version` 또는 `updated_at` 기반 expected value를 사용한다.

```text
client reads version 7
client sends expectedVersion=7
server updates only where version=7
success -> version 8
mismatch -> CONFLICT_VERSION with latest summary
```

반복 시리즈와 역할·entitlement는 last-write-wins를 사용하지 않는다.

## 9. Index 정책

- 모든 RLS membership lookup 경로에 index
- `(household_id, status, due_at)` 및 Today query index
- occurrence materialization 범위 query index
- outbox `(status, retry_at)` partial index
- webhook/provider transaction unique index
- invite token hash unique index
- `created_at` 단독 index를 무분별하게 추가하지 않는다.

실제 query plan과 production-like seed로 검증한다.

## 10. RLS 검증

`matrices/RLS_AUTHORIZATION_MATRIX.csv`의 각 행을 자동 테스트로 구현한다. 최소 actor set:

- anonymous
- authenticated outsider
- active owner/admin/member
- managed child acting context
- removed/suspended membership
- different household member
- service role worker

각 action은 정상 허용뿐 아니라 다음 공격을 포함한다.

- body/query/path에 다른 household UUID 주입
- 다른 가구의 assignee/participant ID 연결
- role/isPlus/actingMember 조작
- soft-deleted row 접근
- 직접 table mutation으로 RPC 우회

## 11. Migration 정책

- forward-only expand/contract
- destructive migration 전 dual-read/write 또는 backfill
- migration마다 rollback이 아니라 recovery plan 기록
- 이전 앱 버전과 최소 한 release window 호환
- schema dump 직접 수정 금지; migration file이 권위
- production 적용 전 local/staging backup·restore drill
