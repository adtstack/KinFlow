# Phase 05 WP05-06 Offline Read Cache Evidence

- Work Package: WP05-06 — bounded encrypted read cache, auth-bound purge, stale/read-only UX and offline mutation safety gate
- 기준 commit: base `a85f262`; implementation은 2026-08-08 현재 WP02-06/WP03/WP04/Phase 05 연속 workspace
- 검증일: 2026-08-08
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2
- 결과: **WP05-06 LOCAL AUTOMATED PASS / REAL-ACCOUNT·REAL-DEVICE FORENSIC DEFERRED**

> 2026-08-09 후속 상태: 이 문서의 outbox 비활성화 기록은 WP05-06 완료 시점의 증거다. WP05-10이 Today/Chores 목록의 단일 scheduled 완료에 한해 local safety Gate와 encrypted outbox를 추가했으며, 상세 범위와 남은 실제 환경 Gate는 `WP05_10_EVIDENCE.md`를 따른다.

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-06 / D-017 / FR-TODAY-004 | PASS FOR BOUNDED ANDROID READ CACHE / OVERALL PARTIAL | 일시적 provider unavailable인 경우에만 active-household와 Today chore first-page snapshot을 복구하고 cached-at, reconnect와 online-only action 설명을 표시한다. Calendar persistent cache와 실제 background/reconnect는 남았다. |
| WP05-06 / D-049 / NFR-SEC-01 | PASS FOR LOCAL SCOPE ENFORCEMENT / OVERALL PARTIAL | exact contract version, normalized auth subject, session ID, household ID와 expiry가 모두 일치해야 읽는다. mismatch, malformed, expired와 corrupt entry는 삭제하고 fail closed한다. 실제 Android Keystore forensic은 남았다. |
| WP05-06 / NFR-PRIV-01 | PASS FOR NEW LOCAL SURFACE | 식별자가 없는 fixed slot 세 개와 environment별 전용 encrypted namespace만 사용한다. payload 크기와 row 수가 bounded하고 auth·notification namespace와 purge surface를 분리했다. |
| WP05-06 / auth lifecycle | PASS FOR LOCAL SYNTHETIC LIFECYCLE / OVERALL PARTIAL | logout, session termination/revocation, account switch, no-active-household와 household change에서 purge 또는 exact replacement한다. purge/write 실패는 authenticated content를 열지 않고 `localPurgeFailed` 또는 repository failure로 닫는다. 실제 membership removal timing은 남았다. |
| WP05-06 / D-043 / D-045 | PASS FOR PLATFORM/DEPENDENCY BOUNDARY | Android composition에서만 persistent cache를 활성화하고 Web은 disabled no-op을 사용한다. 기존 `flutter_secure_storage`를 재사용했으며 Drift, runtime dependency, native permission, DB/API 변경은 없다. |
| WP05-06 / D-018 / NFR-REL-01 | PASS FOR SAFE DENIAL / OUTBOX DEFERRED | encrypted queue만으로는 reconnect membership revalidation, expected-version replay, response-loss recovery와 forensic safety를 증명하지 못하므로 outbox를 구현하지 않았다. cached mutation과 pagination/filter는 controller와 UI 모두에서 거부한다. |

## Storage and Scope Contract

- persistent cache는 Android app composition에서 `FlutterSecureStorage`의 environment별 dedicated namespace를 사용한다. Web composition에는 persistent cache를 주입하지 않는다.
- fixed slot은 `active_household_v1`, `chore_list_v1`, `today_chores_v1`뿐이다. key에 user, session, household 또는 family content를 포함하지 않는다.
- envelope는 exact `contractVersion`, `userId`, `sessionId`, `householdId`, `validatedAt`, `expiresAt`, `payload`를 포함하며 contract version은 `2026-08-08-wp05-06-v1`이다.
- TTL은 최대 24시간이지만 현재 Supabase access-session expiry를 넘지 않는다. session claim의 subject/session/expiry가 없거나 malformed, 서로 불일치하거나 이미 만료되면 cache scope를 만들지 않는다.
- encoded slot은 최대 196,608 bytes이고 Today/chore page는 기존 repository의 최대 100-row contract를 유지한다. oversize write는 거부하고 기존 slot을 제거한다.
- cache payload를 domain object로 바로 신뢰하지 않는다. 기존 strict data payload parser와 repository mapper를 다시 통과시키며 corrupt/invalid payload는 삭제한다.

## Read Fallback and Authoritative Writes

- `temporarilyUnavailable` read에만 cache fallback을 허용한다. unauthenticated, forbidden/not-found, conflict, invalid payload와 mutation failure를 cache로 숨기지 않는다.
- active household의 authoritative success는 cache replacement가 성공한 뒤에만 성공으로 반환한다. authoritative no-household 결과의 cache clear가 실패해도 fail closed한다.
- chore list/Today cache는 exact household와 query만 복구한다. 다른 유효 query의 cache는 삭제하지 않으며 continuation page와 non-first-page 요청은 fallback하지 않는다.
- first page가 server cursor를 포함해도 온전한 first-page snapshot으로 저장하고 일시적 실패 때 복구한다. load-more 결과는 독립적인 persistent history로 확장하지 않는다.
- create/invite, completion/reopen, skip/restore, reschedule/reassign와 series mutation 뒤 관련 read slot을 invalidate한다. invalidation 실패는 mutation 성공을 되돌릴 수 없으므로 다음 authoritative refresh 경계에서 재검증하며 cached UI는 mutation을 애초에 차단한다.

## Auth Lifecycle and Purge

- auth lifecycle은 current cache metadata를 active household snapshot과 함께 보존한다. authoritative snapshot writer 실패나 local purge 실패가 있으면 authenticated app content를 열지 않는다.
- logout, session termination/revocation와 account switch는 기존 local purge participant에 read cache를 포함한다. cache namespace의 `deleteAll`은 auth session과 notification installation namespace와 분리돼 있다.
- no-active-household는 household-bound slots를 clear한다. household change는 active-household scope를 exact replacement하고 새 household query 전까지 이전 chore snapshot을 재사용하지 않는다.
- same session refresh는 새 access-token expiry 범위 안에서 같은 exact scope를 허용한다. 다른 session ID, user ID 또는 household ID는 기존 entry를 삭제한다.

## UI and Offline Mutation Decision

- Today chore 화면은 cached-at 시각, reconnect 안내와 read-only 이유를 en/ko/en-XA로 표시한다.
- cached state에서는 completion/reopen, occurrence/series 변경, create, invite, load-more와 filter 변경을 UI에서 disabled 처리하고 controller도 같은 명령을 거부한다.
- explicit refresh가 authoritative server state를 받으면 cache marker를 제거하고 action을 다시 활성화한다. refresh가 계속 일시 실패하면 유효한 cached snapshot과 read-only 상태를 유지한다.
- completion outbox는 구현하지 않았다. membership가 제거된 뒤 reconnect 전에 queued action이 재생되는 위험, response-loss 후 duplicate/incorrect replay와 삭제 forensic을 현재 local proof만으로 해소할 수 없기 때문이다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused WP05-06 Flutter suite | PASS — 56 tests across secure cache, cached data sources/repository, Supabase scope resolver, auth composition/lifecycle and Today controller/widget |
| full Flutter regression | PASS — 539 tests; local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — `flutter analyze --no-pub`, issue 0 |
| formatter | PASS — 328 Dart files checked, drift 0 |
| localization generation | PASS — exact Flutter `gen-l10n`, en/ko/en-XA generated files current |
| public configuration validation | PASS |
| repository code generation check | PASS — 8 generated files inspected, output delta 0 |
| repository secret scan | PASS — high-confidence secret 0 |
| whitespace | PASS — `git diff --check`, output 0 before evidence finalization; post-document check repeated |

Focused fixtures use only fake secure storage, fake provider/data sources, synthetic UUIDs and deterministic clocks. No production credential, customer account, family data or hosted provider was used.

## Files and Migration

- Offline contract/application/data: `apps/kinflow_app/lib/features/offline/`
- Cache composition and scope: `apps/kinflow_app/lib/app/providers/auth_dependencies.dart`, `apps/kinflow_app/lib/infrastructure/cache/`, `apps/kinflow_app/lib/infrastructure/supabase/supabase_read_cache_scope_resolver.dart`
- Auth and repository integration: auth lifecycle files, household/chore data-source and repository contracts
- Today UI/controller/localization: Today chore controller/screen and en/ko/en-XA ARB/generated localization
- Tests: `secure_read_cache_test.dart`, `cached_read_data_source_test.dart`, `supabase_read_cache_scope_resolver_test.dart` plus auth dependency/lifecycle and Today controller/widget regressions
- Decision: `docs/adr/ADR-0005-bounded-encrypted-offline-cache.md`
- Database migration, RLS, RPC, Edge function, OpenAPI, runtime dependency, Android permission and native source delta for WP05-06: **none**

## Security, Privacy, and Data Impact

- family content는 plaintext preferences, logs, analytics, crash evidence, key name 또는 error string에 기록하지 않는다. 전용 secure-storage value 안에만 bounded snapshot으로 저장한다.
- cache reader는 current authenticated claims를 신뢰의 시작점으로 사용하되 exact subject/session/expiry와 requested household를 envelope에 다시 대조한다.
- corrupt, stale와 scope-mismatched data는 복구 대상으로 취급하지 않고 삭제한다. 삭제 실패나 authoritative active-household write/clear 실패는 content access를 fail closed한다.
- fixed slot과 dedicated namespace는 identifier leakage와 unbounded history를 줄이고 auth/notification purge 실패의 blast radius를 분리한다.
- 이번 작업은 offline mutation authority를 추가하지 않았다. cached family content가 보이는 동안 모든 chore write action은 read-only다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google/Supabase 계정, hosted session refresh/revocation, remote membership removal와 household switch는 **NOT RUN**이다.
- physical Android의 Keystore 파일 잔존, app uninstall/reinstall, OS backup/restore, secure-storage migration과 large-value 성능은 **NOT RUN**이다.
- process death, airplane mode, background/resume와 OEM별 storage behavior의 end-to-end UI 확인은 **NOT RUN**이다.
- Web persistent cache는 제품 결정상 disabled다. iOS persistent cache는 Android Store MVP 범위 밖이며 별도 threat-model 검토 전에는 구현·완료로 주장하지 않는다.

## Remaining Risks and Completion Boundary

1. remote에서 membership가 제거되어도 현재 access session이 아직 유효하고 refresh가 불가능하면 그 session expiry까지 마지막 encrypted snapshot을 읽을 수 있다. TTL을 session expiry로 제한했지만 즉시 remote revocation을 증명하지는 않는다.
2. Android secure storage의 실제 backup/restore, uninstall과 account-switch 파일 잔존은 fake storage가 증명할 수 없다.
3. secure storage의 약 192 KiB value 성능과 OEM별 reliability는 실제 저사양 기기에서 측정하지 않았다.
4. persistent Calendar snapshot과 broad history cache는 구현하지 않았다. Today Calendar에는 기존 in-memory stale/reconnect contract만 남는다.
5. offline completion outbox는 안전성 Gate를 충족하지 않아 비활성이다. 이는 누락된 구현이 아니라 unauthorized/duplicate replay를 막는 의도적 read-only 결정이다.
6. Phase 05 상위 Exit Gate의 hosted notification/provider와 실제 기기 검증은 계속 `PARTIAL`이다.

WP05-06 자체는 local synthetic Android read-cache slice로 완료했다. 실계정·실기기 forensic은 사용자 지시에 따라 기능 개발 대부분이 끝난 뒤 마지막 Gate에 유지한다.

## Rollback

- Android composition의 persistent read cache flag를 disable하면 기존 online-only provider repository로 즉시 복귀한다.
- dedicated read-cache namespace만 `deleteAll`해 auth session과 notification installation storage를 건드리지 않고 제거할 수 있다.
- shipped contract 변경 시 기존 payload를 묵시적으로 migrate하지 않는다. contract-version mismatch로 삭제하거나 새 namespace/version으로 전환한다.
- DB migration이나 remote contract가 없으므로 server rollback은 필요하지 않다.

## Next Entry Condition

- 기능 우선순위의 다음 work package는 Phase 06 WP06-01 billing domain/schema와 household entitlement contract다.
- 먼저 provider-independent entitlement state machine, authoritative server ownership, idempotent event/version contract와 synthetic tests를 구현한다.
- 실제 RevenueCat/Store 계정, sandbox purchase와 실기기 결제 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.
