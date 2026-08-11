# ADR-0005 — Bounded encrypted offline read cache

- 상태: ACCEPTED
- 작성일: 2026-08-08
- 결정일: 2026-08-08
- 결정자: Product owner direction / Engineering
- 관련 요구사항: WP05-06, FR-TODAY-004, NFR-SEC-01, NFR-PRIV-01
- 관련 결정: D-017, D-018, D-043, D-045, D-049
- 관련 위험: RISK-003, RISK-014, RISK-029
- 대체 ADR: 없음

## Context

KinFlow는 offline-first 제품이 아니지만 Android 사용자가 짧은 network 단절이나 cold start 중 최근 Today 정보를 읽을 수 있어야 한다. 동시에 chore 제목·설명·성인 display name은 가족 콘텐츠이며 logout, account/session/household 전환 뒤 다른 사용자에게 남아서는 안 된다. Flutter Web Companion의 공유 PC 잔존 위험 때문에 broad browser cache는 금지되어 있다.

D-045는 지속 cache가 커지면 Drift를 우선 평가하도록 요구한다. 현재 slice는 active-household 한 건과 현재 chore first-page 한 건만 필요하며 기존 Android Keystore-backed `flutter_secure_storage`가 이미 고정·감사돼 있다. 이 작은 범위에 새 SQLite runtime/codegen/native dependency를 추가하면 migration, key management와 삭제 검증 surface가 기능보다 커진다.

## Decision Drivers

- offline cold-start에서도 active household와 최근 Today read를 함께 복구
- account/session/household 교차 노출 fail closed
- family content at-rest 보호와 deterministic purge
- 권한 오류를 stale cache로 숨기지 않음
- cache payload를 domain authority로 신뢰하지 않고 기존 strict parser 재사용
- Web broad cache와 offline mutation의 독립적 Gate 유지

## Options Considered

### Option A — memory-only stale state

- 장점: 저장 데이터와 purge surface가 없다.
- 단점: process death/cold start에서 동작하지 않아 WP05-06의 persistent read 가치가 없다.

### Option B — bounded fixed-slot encrypted snapshot

- 장점: 기존 secure storage와 purge contract를 재사용하고 key에 식별자를 넣지 않으며 작은 snapshot을 빠르게 제거할 수 있다.
- 단점: query/history가 늘면 key-value blob 크기와 rewrite 비용이 커지고 schema migration/query 기능이 부족하다.

### Option C — Drift/SQLite cache database

- 장점: 여러 query, row-level TTL, bounded eviction과 migration에 적합하다.
- 단점: 현재 두 slot에 비해 runtime/codegen/native dependency와 threat/purge/migration surface가 크다. database encryption key와 file forensic 정책도 별도 결정이 필요하다.

## Decision

1. Option B를 Android Store MVP의 WP05-06 read-cache baseline으로 채택한다. Flutter Web에서는 compose하지 않는다.
2. cache는 auth와 notification storage와 분리된 environment별 `kinflow_read_cache_<environment>_v1` encrypted namespace를 사용한다.
3. storage key는 allowlisted fixed slot뿐이다. user/household/session ID나 family content를 key에 사용하지 않는다.
4. envelope는 exact contract version, auth user ID, Supabase `session_id`, household ID, validated/expiry UTC timestamp와 payload만 허용한다.
5. entry TTL은 최대 24시간과 현재 access-session expiry 중 이른 시각이다. current session이 없거나 expired, `session_id`가 없거나 scope가 다르면 cache를 열지 않고 해당 slot을 삭제한다.
6. provider의 explicit `temporarilyUnavailable` read failure만 cache fallback 대상이다. unauthenticated, forbidden/not-found, invalid payload와 mutation failure는 cache가 가리지 않는다.
7. payload는 encoded 196,608 bytes와 기존 page row limit 안에서만 쓴다. decode 뒤 기존 strict payload parser와 repository mapper를 다시 통과한다.
8. cached UI는 cached-at 시각과 read-only 상태를 명확히 표시한다. stale expected version을 근거로 하는 모든 mutation은 controller와 UI에서 차단한다.
9. logout/account switch/session termination/no-active-household는 전용 namespace 전체를 purge한다. active household 변경은 old slot을 exact replacement한다. purge 실패는 protected route를 잠그는 기존 auth policy를 따른다.
10. completion outbox는 별도 Gate다. encrypted queue만으로 충분하지 않으며 auth subject/session/household/expected version/TTL/idempotency와 reconnect 시 server membership 재검증, response-loss replay 및 UI reconciliation을 함께 증명해야 한다.

2026-08-09 follow-up: WP05-10은 Android Today/Chores 목록의 scheduled 완료 한 건에만 위 Gate의 local 구현을 승인했다. 전용 encrypted slot, exact actor member와 session scope, 30분/session-clamped TTL, target 권한·version 재검증, same-key response-loss reconciliation, 최대 3회 선행 기록과 terminal 재생 중지를 함께 적용한다. 다른 offline mutation과 notification target action은 차단하며 D-018은 실제 기기·hosted·두 기기 검증 전까지 `PROVISIONAL`이다.

## Threat Model

| 위협 | 통제 | 잔여 위험 |
|---|---|---|
| logout 뒤 다음 사용자가 이전 가족 콘텐츠 열람 | 전용 encrypted namespace가 auth purge participant이며 purge 실패 시 auth lock | OS/plugin 삭제 결함은 실제 device forensic Gate 필요 |
| 같은 사용자 account session 교체 뒤 오래된 cache 재사용 | user ID뿐 아니라 Supabase `session_id` exact match | provider가 claim을 제공하지 않으면 cache unavailable로 fail closed |
| household 전환 또는 탈퇴 뒤 이전 snapshot 노출 | household envelope match, active slot replacement, no-active purge, 짧은 session-bounded TTL | membership이 다른 기기에서 제거된 직후 현재 token expiry까지 read 가능 |
| cache tampering/corruption | encrypted at rest, exact envelope/payload keys, strict parser/mapper, invalid slot 삭제 | rooted device와 compromised process는 Store threat model 밖 |
| unbounded family content 축적 | fixed three slots, one first page, per-slot byte cap, no history | future query expansion에는 Drift 재평가 필요 |
| stale state 기반 destructive write | cached marker와 controller/UI dual guard, online-only mutation | 별도 화면이 cache marker를 우회하지 않도록 회귀 필요 |
| shared browser persistence | Web composition disabled | Web Companion 별도 session-only UX 필요 |

## Consequences

### Positive

- 새 DB/API/native permission/runtime dependency 없이 offline cold-start read를 제공한다.
- 기존 auth lifecycle purge 실패 lock이 cache에도 동일하게 적용된다.
- strict scope와 TTL이 맞지 않으면 stale content 대신 unavailable 상태를 선택한다.

### Negative / Debt

- 현재 cache는 active query 한 개와 first page만 보존하므로 offline filter 변경, pagination, history와 Calendar 전체 탐색을 지원하지 않는다.
- remote membership removal은 offline에서 즉시 알 수 없고 현재 session-bounded expiry까지 read 가능하다.
- secure key-value blob이 196,608 bytes에 가까워지면 write latency와 platform storage 특성을 실제 기기에서 측정해야 한다.
- iOS가 다시 범위에 들어오면 Keychain large-value 사용을 그대로 승인하지 않고 Drift/SQLCipher 또는 protected file storage를 재검토한다.

## Validation

- unit: exact envelope, scope/session/TTL/size/corruption와 purge
- repository/data: transient-only fallback, strict payload reparse, query mismatch, active household cold start
- application/UI: stale label, online-only action, refresh recovery와 dual mutation guard
- actual device: Android Keystore backup/restore, logout residue, account/member removal과 process restart forensic는 마지막 Gate

## Rollback / Revisit Trigger

- rollback: cache decorator와 composition을 disable하고 전용 namespace를 purge하면 provider-only repository로 복귀한다.
- 재검토: 세 개 초과 query slot, 100개 초과 row, 196,608-byte 초과, offline Calendar/history 요구, multi-household UI, iOS 재도입, cache write p95 50ms 초과, 또는 purge/forensic 결함 발견 시 Drift와 database encryption을 새 ADR로 평가한다.
