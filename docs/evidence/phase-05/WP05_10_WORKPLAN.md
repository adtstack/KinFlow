# Phase 05 WP05-10 Bounded Chore Completion Outbox Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-09)`
- 범위: Android Store MVP의 Today/Chores 목록에서 scheduled occurrence 완료 한 건을 auth/session/household/member/version/TTL/idempotency에 묶어 encrypted outbox에 저장하고 foreground reconnect에서 권한을 다시 확인한 뒤 재생한다.
- 제외: 완료 취소, 역할·초대·삭제·결제·반복 시리즈 및 다른 모든 offline write, notification target 상세 action, background worker, iOS/Web persistence, 실계정·실기기 검증

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP05-10 / D-018 / FR-CHORE-004 | cached scheduled occurrence 중 server-derived `canSetCompletion`이 true였던 한 건만 완료 intent로 저장한다. 완료 취소와 두 번째 다른 intent는 거부한다. |
| WP05-10 / D-048 / NFR-REL-01 | item은 original expected version과 idempotency key를 보존한다. foreground 재생 전 authoritative target read로 membership, action authority, state와 version을 다시 확인하고 같은 key로만 재생한다. |
| WP05-10 / D-049 / NFR-SEC-01 | exact auth subject, Supabase session ID, active household와 actor member가 모두 일치해야 읽고 재생한다. 재인증·계정·가구·구성원 변경, expiry와 corruption은 자동 재생하지 않고 purge한다. |
| WP05-10 / NFR-PRIV-01 | dedicated encrypted fixed slot에는 UUID command metadata만 저장한다. title, description, display name, email, token과 raw provider error를 저장·로그·분석하지 않는다. |
| WP05-10 / D-017 / D-023 | replay는 initial load, explicit refresh와 foreground resume에서만 수행한다. 역할·초대·삭제·결제·recurrence definition 등 기존 online-only 경계는 유지한다. |
| WP05-10 / NFR-A11Y-01 / NFR-I18N-01 | queued, syncing, reconciled, needs-attention와 discarded 상태를 en/ko/en-XA ARB 기반 live-region UI와 명시적 discard/retry recovery로 표시한다. |

## Storage and Replay Contract

- fixed slot: `kinflow.chore_completion_outbox.v1`
- exact envelope: `contractVersion`, `userId`, `sessionId`, `householdId`, `actorMemberId`, `occurrenceId`, `expectedVersion`, `requestedStatus`, `idempotencyKey`, `createdAt`, `expiresAt`, `attemptCount`
- TTL: 최대 30분, 현재 access-session expiry와 비교해 더 이른 시각
- automatic replay: 최대 3회이며 target read 전에 증가한 attempt를 먼저 durable write한다.
- encoded size: 최대 4,096 bytes
- response-loss recovery: target이 이미 `completed`이고 version이 `expectedVersion + 1`이면 재호출 없이 성공으로 reconcile한다.
- mutation replay: target이 `scheduled`, exact expected version, `canSetCompletion=true`일 때만 original key로 호출한다.
- transient failure만 bounded retry한다. conflict, forbidden/unavailable target, invalid payload와 mismatched success는 item을 제거하고 authoritative data를 표시한다.
- terminal item 삭제가 실패하면 attempt를 최대값으로 durable write해 다음 foreground 진입에서도 자동 재생하지 않고 authoritative 상태와 needs-attention 복구만 표시한다.
- secure write 또는 attempt update 실패 시 optimistic UI와 network side effect 모두 실행하지 않는다.

## UX and Composition

- cached scheduled card의 완료 버튼만 queue gate가 열려 있을 때 활성화한다. 완료 취소, 메뉴 mutation, create/invite/load-more는 계속 disabled다.
- queue 성공은 먼저 encrypted write를 완료한 뒤 desired completed presentation과 localized queued banner를 보인다.
- banner는 item discard를 제공한다. discard 뒤 cached authoritative snapshot을 다시 읽어 optimistic presentation을 제거한다.
- reconnect preflight는 Today/overdue 목록을 읽기 전에 한 번 수행하여 두 목록이 같은 authoritative 결과를 보게 한다.
- Android persistent read-cache composition과 같은 Gate에서만 전용 outbox namespace를 주입한다. Web/iOS/bootstrap fallback은 unavailable implementation으로 fail closed한다.

## Test Plan

- entity: canonical UUID/time/status, 30분 TTL, attempt 0..3, exact next-attempt invariant
- secure store: exact keys/version/size/corruption, user/session/household/member mismatch, session expiry clamp, expiry purge, serialized single-slot writes, logout/household purge
- controller: cached completion queue, unavailable/occupied/reopen rejection, write-before-optimistic order, online transient same-key queue, internal/non-transient no-queue
- replay: membership/authority target revalidation, expected-version replay, already-applied reconcile, transient bounded retry, max-attempt attention, terminal discard, runtime-policy pause
- orchestration: replay preflight before Today/overdue reads on initial/resume/refresh
- widget: completion-only cached affordance, queued/syncing/reconciled/attention/discarded banners, discard recovery, en/ko/en-XA generated localization
- composition: dedicated namespace, Android-only enablement, purge participant and unavailable fallback
- focused/full Flutter tests, analyzer, formatter, localization/codegen/config/secret/whitespace gates

## DB/API Impact

- database migration, schema, RLS, grant, RPC, Edge function과 remote DTO 변경은 없다.
- 기존 `get_chore_occurrence_action_target`와 `set_chore_occurrence_completion` 계약만 재사용한다.
- notification target 상세 action은 기존 WP05-09대로 online-only이며 이번 outbox를 주입하지 않는다.

## Rollback

- `UnavailableChoreCompletionOutbox`를 compose하면 WP05-06의 cached completion read-only behavior로 복귀한다.
- 전용 outbox secure-storage namespace만 `deleteAll`해 auth, notification, read cache와 guided setup storage를 건드리지 않고 제거한다.
- server/data rollback과 migration은 필요 없다.

## Completion Boundary

- fake secure storage, deterministic clock와 fake repository로 queue/replay/response-loss/purge/UI invariant가 통과하고 전체 회귀·analyzer·formatter가 깨끗하면 WP05-10을 `LOCAL IMPLEMENTED`로 기록한다.
- D-018의 실제 운영 Gate는 physical Android Keystore/process death/airplane mode와 hosted membership/session/two-device 검증까지 `PARTIAL`로 유지한다.
- 실제 계정과 실기기 검증은 사용자 지시에 따라 기능 개발 대부분이 끝난 뒤 마지막 Gate에서 수행한다.

## Local Result

- Android read-cache Gate와 분리된 secure-storage namespace의 단일 fixed slot, exact auth/session/household/member binding, 30분·session-clamped TTL과 3회 선행 기록 replay를 구현했다.
- cached scheduled completion과 online transient completion만 original expected version/idempotency key로 저장한다. 완료 취소와 다른 cached mutation, notification target 상세 action은 계속 online-only다.
- initial load, refresh, resume와 overdue source retry는 authoritative target 재인가를 먼저 수행한다. 저장 명령을 처리한 경우 관련 Today/overdue read를 그 뒤에 실행하고, 일반 overdue 오류는 기존 source-isolated retry를 유지한다.
- response-loss already-applied reconciliation, runtime-policy pause, terminal discard, 삭제 실패 replay exhaustion, logout/household purge와 localized queued/recovery/discard UI를 fake storage/provider로 검증했다.
- 전체 Flutter 회귀, analyzer, formatter와 repository Gate의 최종 수치는 `WP05_10_EVIDENCE.md`에 기록한다. 실제 Keystore·airplane mode·hosted membership/session·두 기기 race는 마지막 Gate다.
