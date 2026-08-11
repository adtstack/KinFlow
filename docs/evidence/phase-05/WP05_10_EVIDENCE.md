# Phase 05 WP05-10 Bounded Chore Completion Outbox Evidence

- Work Package: WP05-10 — Android single-slot encrypted scheduled-completion outbox and foreground reauthorization
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·PHYSICAL-DEVICE GATE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-10 / D-018 / FR-CHORE-004 | PASS FOR ONE BOUNDED ANDROID COMMAND / OVERALL PARTIAL | Today/Chores의 cached scheduled occurrence 중 server-derived `canSetCompletion=true`인 한 건만 completed intent로 저장한다. 완료 취소와 다른 offline write는 controller와 UI에서 계속 거부한다. |
| WP05-10 / D-048 / NFR-REL-01 | PASS FOR LOCAL REPLAY INVARIANTS / OVERALL PARTIAL | original expected version과 idempotency key를 보존하고 authoritative target 재인가 뒤 exact request만 재생한다. already-applied response loss, 3회 선행 기록, terminal replay stop과 목록 선행 순서를 자동 검증했다. |
| WP05-10 / D-049 / NFR-SEC-01 | PASS FOR LOCAL SCOPE ENFORCEMENT / OVERALL PARTIAL | exact auth subject, Supabase session ID, household, actor member, UTC TTL과 contract version이 모두 일치해야 읽는다. mismatch·expiry·corruption·logout·household transition은 purge한다. 실제 Android Keystore forensic은 남았다. |
| WP05-10 / NFR-PRIV-01 | PASS FOR NEW LOCAL SURFACE | dedicated encrypted fixed slot에는 UUID command metadata와 시간·version·attempt만 저장한다. title, description, display name, email, token, provider error, log와 analytics를 추가하지 않았다. |
| WP05-10 / D-017 / D-023 | PASS FOR FOREGROUND-ONLY BOUNDARY | initial load, explicit refresh, resume와 overdue retry에서만 preflight한다. background worker와 notification target 상세 action, role/invite/delete/billing/series offline mutation은 없다. |
| WP05-10 / NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION / DEVICE PARTIAL | queued, syncing, paused, reconciled, needs-attention, discarded, expired, unavailable와 occupied 상태를 en/ko/en-XA ARB 기반 live region과 명시적 discard action으로 제공한다. 실기기 TalkBack은 남았다. |

## Storage and Scope

- fixed key는 `kinflow.chore_completion_outbox.v1`, contract version은 `2026-08-09-wp05-10-v1`이다.
- envelope은 exact 12 fields만 허용한다: contract/user/session/household/actor/occurrence/version/requested-status/idempotency/created/expiry/attempt.
- encoded value는 4,096 bytes 이하이고 capacity는 한 건이다. 다른 occurrence가 slot을 점유하면 기존 item을 덮어쓰지 않는다.
- TTL은 생성 후 최대 30분과 current access-session expiry 중 이른 시각이다. canonical UTC, UUID, exact key set과 `requestedStatus=completed`를 다시 검증한다.
- Android persistent read-cache composition과 같은 platform Gate에서만 전용 `FlutterSecureStorage` namespace를 주입한다. namespace는 read cache, auth, notification과 guided setup에서 분리되고 Android backup migration을 사용하지 않는다.
- unavailable/bootstrap/Web/iOS composition은 no-op 구현으로 fail closed한다. 새 database, Drift, runtime dependency, native permission과 plaintext preference를 추가하지 않았다.

## Queue and Replay Behavior

1. cached scheduled completion은 encrypted enqueue가 성공한 뒤에만 local completed presentation을 보인다.
2. online completion은 typed `temporarilyUnavailable`일 때만 이미 전송한 original command ID와 expected version으로 enqueue한다. raw exception과 다른 failure는 저장하지 않는다.
3. foreground preflight는 attempt를 먼저 durable write한 뒤 cache fallback이 없는 exact action target을 읽는다.
4. target이 scheduled/exact version/`canSetCompletion=true`일 때만 same-key completion을 호출한다.
5. target이 already completed at expected version + 1이면 두 번째 mutation 없이 reconcile한다.
6. transient target/mutation failure만 최대 3회 유지한다. 최대값 이후에는 authoritative state와 needs-attention/discard recovery만 제공한다.
7. forbidden/missing/stale/invalid target 또는 mismatched success는 terminal이다. slot 삭제가 실패해도 attempt를 최대값으로 다시 써 현재·다음 foreground 자동 replay를 중단한다.
8. runtime-policy Chores mutation block은 attempt와 target/network I/O 전에 paused 상태로 멈춘다.

## UI and Orchestration

- initial Today 진입, refresh와 resume는 outbox resolution을 await한 뒤 Today/overdue 목록을 읽는다. widget automation은 `target → mutation → list` 순서를 고정한다.
- overdue source 오류 재시도도 먼저 preflight한다. 실제 stored intent를 처리한 경우 관련 primary/overdue 목록을 함께 조정하고, item이 없으면 기존 overdue-only source isolation을 유지한다.
- pending item이 있는 동안 duplicate completion, reopen, create, invite, menu mutation, filter와 pagination을 비활성화한다.
- queued occurrence는 cached list에 있을 때만 desired completed presentation을 표시한다. exhausted 또는 terminal-clear-failed item은 authoritative scheduled state를 보존한다.
- explicit discard가 성공하면 slot과 optimistic overlay를 제거한다. clear 실패는 needs-attention 상태로 남기고 자동 mutation을 재개하지 않는다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused WP05-10 and Today impact suite | PASS — 99 tests across entity, secure store, controller, UI orchestration, composition/purge, Today source isolation and architecture |
| full Flutter regression | PASS — 1,255 tests; existing local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — `flutter analyze --no-pub`, issue 0 |
| Dart formatter | PASS — 676 files checked, drift 0 |
| localization and generated code | PASS — build runner wrote 0 outputs; 8 generated files current |
| public configuration | PASS — examples valid and allowlisted |
| repository secret scan | PASS — high-confidence finding 0 |
| repository Node contracts | PASS — 141/141; workflow and supply-chain contract passed |
| whitespace | PASS — `git diff --check` output 0 before final evidence write; final check repeated at handoff |

Focused tests cover exact envelope/key/size/TTL/session clamp, mismatch/corruption/expiry purge, one-slot occupancy, durable attempt and terminal exhaustion, cached write-before-optimistic order, transient same-key queue, target authorization/version validation, response-loss reconciliation, runtime-policy pause, logout/household purge, shared Today/overdue state, explicit discard and foreground ordering. Fixtures use only synthetic UUIDs, fake secure storage, deterministic clocks and fake repositories.

## Files and Impact

- Contract and plan: `docs/contracts/chore-completion-outbox.yaml.md`, `docs/evidence/phase-05/WP05_10_WORKPLAN.md`
- Domain/application: `pending_chore_completion.dart`, `chore_completion_outbox.dart`, Today controller/state
- Data/composition: `secure_chore_completion_outbox.dart`, auth dependency secure-store composition and bootstrap/provider overrides
- Presentation: Today screen/provider, en/ko/en-XA ARB and generated localization
- Tests: pending entity, secure outbox, outbox controller, Today/Chore widgets, auth composition and architecture guards
- Database migration, schema, RLS, grant, RPC, Edge Function, OpenAPI, runtime dependency and native permission delta: **none**

## Security and Privacy Boundary

- authoritative membership/action authorization remains server-side. Cached `canSetCompletion` only permits durable intent capture and never authorizes replay.
- secure item is bound to the current user/session/household/actor and is purged on any mismatch before target read or mutation.
- queue write and attempt persistence failure stop optimistic presentation or replay. Storage errors are converted to stable UI states without raw exception text.
- no title, description, display name, email, access/refresh token, provider receipt or raw response is serialized, logged or sent to analytics.
- notification target detail remains an independent online-only controller; this outbox cannot be reached from that route.

## Manual and Deferred Validation

- 사용자 지시에 따라 actual Supabase account/session refresh/revocation, remote membership/role/assignment removal와 two-device race는 **NOT RUN**이다.
- physical Android Keystore file residue, process death, airplane mode/reconnect, app backup/restore, uninstall/reinstall와 low-storage/secure-write failure는 **NOT RUN**이다.
- actual phone/tablet 200% text, TalkBack live-region announcement와 rapid resume/refresh interaction은 **NOT RUN**이다.
- iOS and Web persistent outbox는 범위 밖이며 별도 platform/threat decision 전까지 disabled다.

## Remaining Risks and Completion Boundary

1. fake secure storage는 Android Keystore가 process death, OS backup과 low-storage 상황에서 동일한 atomicity/deletion behavior를 보인다고 증명하지 않는다.
2. authoritative target revalidation은 구현됐지만 hosted membership removal과 session rotation의 timing은 실제 계정으로 확인해야 한다.
3. two-device concurrent completion/reopen race는 server expected-version/idempotency contract에 의존하며 hosted device evidence가 남았다.
4. automatic replay는 foreground trigger뿐이다. 사용자가 앱을 다시 열거나 refresh하기 전에는 queue가 서버에 반영되지 않는다.
5. D-018과 T-SYNC-01은 local slice가 통과했지만 physical/hosted Gate 전까지 `PARTIAL`/`PROVISIONAL`을 유지한다.

WP05-10 자체는 local synthetic Android slice로 완료했다. 실계정·실기기 검증은 사용자 지시에 따라 기능 개발 대부분이 끝난 뒤 마지막 Gate에 유지한다.

## Rollback

- `UnavailableChoreCompletionOutbox`를 compose하면 cached completion도 WP05-06 read-only behavior로 즉시 돌아간다.
- dedicated chore-completion namespace만 `deleteAll`해 auth, notification, read cache와 guided setup storage를 건드리지 않고 제거할 수 있다.
- remote schema/API 변경과 data migration이 없으므로 server rollback은 필요 없다.
