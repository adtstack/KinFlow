# Phase 05 WP05-06 Offline Read Cache Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-08)`
- 범위: Android Store MVP의 authenticated cold-start에서 최근 active-household와 Today chore first-page snapshot을 제한적으로 복구하고, stale/read-only 상태와 안전한 purge를 제공한다.
- 제외: Flutter Web broad cache, 역할·초대·삭제·결제·반복 시리즈 offline mutation, 무제한 history/calendar cache, background sync authority, 실계정·실기기 forensic 검증

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP05-06 / D-017 / FR-TODAY-004 | provider가 일시적으로 unavailable일 때만 최근 Today chore snapshot을 표시하고 cached-at 시각과 read-only 이유를 UI에 노출한다. 권한·invalid payload·not-found 결과를 cache로 가리지 않는다. |
| WP05-06 / D-049 / NFR-SEC-01 | cache envelope는 environment별 전용 encrypted storage 안에서 exact user ID, Supabase session ID, household ID, contract version과 expiry로 namespace한다. 하나라도 다르면 fail closed하고 slot을 삭제한다. |
| WP05-06 / NFR-PRIV-01 | cache key에는 사용자·가구 식별자나 family content를 넣지 않고 fixed slot만 사용한다. payload는 기존 Android Keystore-backed secure storage namespace에만 저장하며 크기와 row 수를 제한한다. |
| WP05-06 / FR-AUTH lifecycle | logout, account switch, session termination/revocation, no-active-household와 household change 시 cache를 purge 또는 exact replacement한다. purge 실패는 기존 `localPurgeFailed` lock 경계를 유지한다. |
| WP05-06 / D-043 / D-045 | Web에서는 persistent read cache를 compose하지 않는다. 이번 bounded three-slot snapshot은 기존 secure-storage dependency를 재사용하고 Drift를 추가하지 않으며 threat model과 확장 재검토 조건을 ADR에 기록한다. |
| WP05-06 / D-018 / NFR-REL-01 | completion outbox는 auth subject, session, household, expected version, TTL, idempotency와 reconnect membership revalidation을 모두 증명한 뒤에만 enable한다. Gate를 통과하지 못하면 cached content는 read-only다. |

## Storage and Contract

- fixed slots: `active_household_v1`, `chore_list_v1`, `today_chores_v1`
- envelope: exact `contractVersion`, `userId`, `sessionId`, `householdId`, `validatedAt`, `expiresAt`, `payload`
- contract version: `2026-08-08-wp05-06-v1`
- TTL: 최대 24시간이지만 현재 Supabase access-session expiry보다 길 수 없다.
- size: encoded slot당 최대 196,608 bytes, Today page 최대 기존 100-row repository contract
- cache fallback: `temporarilyUnavailable` read만 허용. unauthenticated, forbidden/not-found, invalid payload, conflict와 mutation에는 허용하지 않는다.
- cache entry는 domain object로 직접 신뢰하지 않고 기존 strict data payload parser와 repository mapper를 다시 통과한다.

## UX and Mutation Policy

- persistent cache에서 복구된 화면에는 cached-at 시각, reconnect 안내와 online-only action 설명을 표시한다.
- cached state에서는 completion/reopen, occurrence/series 변경, create, invite와 load-more를 UI와 controller 양쪽에서 차단한다.
- explicit refresh 성공 시 cache marker를 제거하고 authoritative server state로 교체한다.
- refresh 실패 시 같은 valid cached snapshot을 유지한다. expiry 또는 scope mismatch면 빈 cache로 취급한다.

## Test Plan

- cache envelope exact key/version/user/session/household/TTL/size/corruption 검사
- session refresh same-session 허용, account/session/household switch와 expiry 거부·삭제
- active-household network write, cold-start temporary fallback, absent/unauthenticated purge
- chore first-page network write, exact-query fallback, query/continuation mismatch와 non-transient failure no-fallback
- repository metadata propagation과 strict mapper 재검증
- controller cached read-only defense, refresh recovery, load-more/mutation 차단
- widget stale/read-only banner와 disabled online actions, en/ko/en-XA generated localization
- auth composition cache namespace isolation과 logout purge participant
- focused/full Flutter tests, analyzer, formatter, codegen/config/secret/dependency/whitespace gates

## Rollback

- persistent cache composition을 disable하면 기존 provider repositories와 online-only behavior로 즉시 복귀한다.
- 전용 cache namespace를 `deleteAll`해 auth/notification secure storage와 독립적으로 제거한다.
- runtime dependency, DB migration, RLS, RPC, Edge function과 native permission 변경은 없다.
- shipped cache contract를 바꿀 때 기존 slot을 해석하지 말고 version mismatch로 삭제하거나 새 namespace/version으로 전환한다.

## Completion Boundary

- fake secure storage와 fake provider로 cold-start cache, stale UI, scope/expiry/purge/read-only invariant가 결정적으로 통과하면 read-cache slice를 `LOCAL IMPLEMENTED`로 기록한다.
- completion outbox는 위 Gate가 증명될 때만 같은 WP의 후속 sub-slice로 추가한다. 그렇지 않으면 D-017의 read-only 정책을 유지하고 이유를 evidence에 남긴다.
- 실제 Android Keystore 파일 잔존, backup/restore, session expiry와 membership removal forensic 검증은 사용자 지시에 따라 마지막 실계정·실기기 Gate다.

## Local Result

- Android composition의 전용 encrypted storage에 active household, chore list, Today first-page 세 슬롯을 구현했다. Web composition은 계속 비활성이다.
- exact contract/user/session/household/TTL/size 검증, strict parser 재검증, auth lifecycle purge와 cached read-only 이중 방어를 구현했다.
- Flutter 전체 회귀는 539 pass와 local-connectivity opt-in 1 skip, analyzer issue 0, formatter drift 0으로 통과했다.
- completion outbox는 membership revalidation, response-loss 복구와 forensic Gate가 모두 증명되지 않아 구현하지 않았다. cached content는 의도적으로 read-only다.

> 2026-08-09 후속 상태: 위 결과는 WP05-06 시점의 결정이다. WP05-10이 목록의 단일 scheduled 완료에 한해 membership/action target 재검증과 response-loss 복구를 local synthetic evidence로 추가했다. 실제 기기 forensic은 계속 마지막 Gate다.
