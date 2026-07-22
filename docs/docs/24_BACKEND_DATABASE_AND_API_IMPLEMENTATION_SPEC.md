# 24. 백엔드, 데이터베이스, API 구현 스펙

- 상태: ACCEPTED
- Backend: Supabase Auth/PostgreSQL/RLS/Edge Functions

## 1. Repository layout

```text
supabase/
├─ config.toml
├─ migrations/
├─ functions/
│  ├─ _shared/
│  ├─ accept-invite/
│  ├─ transfer-owner/
│  ├─ billing-webhook/
│  └─ request-account-deletion/
├─ tests/
└─ seed.sql
```

Edge Function은 TypeScript/Deno를 유지한다. Flutter와 동일 언어로 맞추기 위해 서버를 Dart로 바꾸지 않는다.

## 2. Migration

- timestamped immutable file
- one concern per migration
- schema, RLS, function, index가 review 가능
- seed는 deterministic/non-production
- destructive operation은 expand/backfill/contract
- migration hash를 evidence에 기록

## 3. RLS

모든 public/authenticated family table에 RLS. 새 table을 RLS 없이 생성하면 CI 실패. view/function 권한을 명시하고 public execute를 제거한다.

## 4. Direct query vs command

Direct read 예:

- active household list
- Today read model
- household member list
- occurrence detail

RPC/Edge command 예:

- household create/owner setup
- invite accept
- role/owner transition
- recurrence revision
- delete/export
- billing assignment

## 5. Edge Function 공통 middleware

- request ID
- auth token 검증
- CORS exact allowlist (Web)
- body size/content type
- schema validation
- idempotency
- rate limit
- structured redacted log
- stable error envelope
- timeout/cancellation

## 6. Auth context

서버는 access token에서 user를 얻고 active membership을 DB에서 조회한다. body의 userId/role/household ownership을 신뢰하지 않는다. service role로 query할 때도 application authorization을 명시적으로 수행한다.

## 7. Transaction 예: 초대 수락

```text
validate token hash/expiry/revoke/use
lock invite
verify authenticated user
ensure not member/conflicting state
insert membership
increment use count
emit household.member_joined
commit
```

같은 idempotency key는 같은 membership 결과를 반환한다.

## 8. Recurrence materialization

- series/revision/exception을 읽음
- household timezone/local intent 해석
- bounded horizon occurrence upsert
- unique series+scheduled-local/instant key
- completed past occurrence 변경 금지
- revision effective_from 이후만 재생성
- job retry idempotent

## 9. Today read model

입력:

- authenticated user
- active household
- household local date
- optional member filter

출력:

- chores/events ordered sections
- server generated at
- household timezone
- entitlement/limit summary 최소 정보
- cursor/next window 필요 시

UI 전용 과도한 denormalization은 versioned contract로 관리한다.

## 10. Billing webhook

- provider verification
- event unique
- raw payload encrypted/limited retention 또는 필요한 필드만 저장
- customer/transaction upsert
- entitlement recompute
- outbox event
- duplicate success
- unknown/malformed quarantine

## 11. Worker

- claim with `FOR UPDATE SKIP LOCKED` 또는 equivalent lease
- heartbeat/lease expiry
- bounded retries+jitter
- dead letter와 manual replay
- poison message 격리
- worker identity 최소 권한

## 12. Rate limit

고위험:

- auth recovery
- invite create/accept/short-code lookup
- deletion/export
- billing refresh
- support/admin actions

user, IP, household, token fingerprint 중 적절한 key를 조합하며 개인정보를 raw log하지 않는다.

## 13. OpenAPI와 Dart client

`contracts/openapi-edge.yaml`은 Edge command의 권위다. Phase 01/02에서 수동 typed client 또는 승인된 generator를 선택한다. generator 출력이 domain type이 되지 않으며 DTO adapter 뒤에 둔다.

## 14. 성능

- query budget와 index
- explain analyze on representative seed
- N+1 방지
- Realtime publication 최소화
- large JSON payload 제한
- list pagination
- connection/function concurrency 관측

## 15. DB 검증 Gate

- clean reset/migration
- pgTAP/RLS matrix
- cross-household FK attack
- idempotency concurrency
- recurrence deterministic fixture
- webhook replay/out-of-order
- backup restore
- old/new client compatibility
