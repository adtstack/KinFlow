# Phase 10 WP10-03B Web Route Recovery Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)**
- Vertical slice: protected direct URL → privacy-safe sign-in continuation → session-expiry re-auth return → logout/account/household isolation → safe 404/unavailable recovery
- Requirements: FR-AUTH-004, FR-PLAT-011, NFR-WEB-001, NFR-WEB-004
- Decisions: D-032, D-038, D-070
- Contract: `docs/contracts/web-route-recovery.yaml.md`
- Test: T-WEB-02

## Product boundary

1. 보호 route를 비인증 상태로 열면 로그인 URL에는 raw path, resource UUID, 임의 query 또는 fragment 대신 고정 continuation marker만 남긴다.
2. 같은 앱 실행 중 session expiry/revoke 후 재인증하면 검증된 상세 route를 복구한다. 로그인 화면이 refresh되면 marker가 가리키는 상위 기능까지만 복구한다.
3. 명시적 logout, 사용자 변경과 active household 변경은 이전 상세 route를 폐기하고 `/today` 또는 marker 없는 sign-in으로 이동한다.
4. 유효한 집안일 생성 route에서만 canonical `due=YYYY-MM-DD`를 메모리에 보존한다. Calendar import처럼 route-extra가 필요한 화면은 상위 Calendar로 복구한다.
5. unknown route와 잘못된 UUID/date route는 공용 404 화면을 사용한다. authoritative not-found/forbidden은 기존 Chore/Calendar 공용 unavailable 상태를 유지해 존재 여부를 구분하지 않는다.
6. 실제 browser history/BFCache와 non-root refresh는 hosted SPA rewrite 결정이 필요하므로 마지막 Web 통합 Gate로 남긴다.

## DB, API and dependency impact

- DB migration, RLS, RPC, Edge contract와 server payload 변경은 없다.
- runtime 또는 dev dependency를 추가하지 않는다.
- route intent는 process memory에만 존재하고 storage, log 또는 analytics로 보내지 않는다.
- 기존 repository authorization과 server-side not-found/forbidden 합성 계약을 변경하지 않는다.

## Implementation plan

1. route 상수를 router construction에서 분리하고 route recovery policy를 독립적으로 테스트 가능하게 만든다.
2. 알려진 route를 exact in-memory destination과 고정 coarse continuation marker로 분류한다.
3. guard가 session expiry/revoke만 exact intent를 유지하고 logout, provider failure, identity/household 전환에서는 폐기하도록 auth transition hook을 연결한다.
4. GoRouter redirect chain이 state 전환보다 먼저 평가될 수 있는 logout 경합에서도 이전 route가 재수집되지 않도록 safe routing boundary를 유지한다.
5. unknown/invalid dynamic route를 내부 safe 404 route로 통일하고 unauthenticated onboarding 접근도 sign-in으로 fail closed한다.
6. 이미 인증된 direct route도 render 전에 canonicalize하여 임의 query/fragment가 browser history에 남지 않게 하되, trusted process-memory `state.extra`가 필요한 Calendar import는 예외로 둔다.
7. guard/policy 단위 테스트와 실제 app router 위젯 테스트로 expiry 복귀, URL scrub, logout 미복귀와 공용 404를 검증한다.

## Automated verification

- fixed continuation marker allowlist와 duplicate/unknown marker rejection
- UUID, arbitrary query, fragment와 callback-like 값의 sign-in URL 제거
- exact same-runtime expiry recovery와 refreshed sign-in coarse recovery
- explicit logout과 household switch의 prior-route 폐기
- canonical chore due query와 non-replayable import fallback
- 이미 인증된 direct URL의 arbitrary query/fragment 제거와 Calendar import `state.extra` 보존
- unknown/invalid route의 공용 404, Chore/Calendar not-found-or-forbidden 공용 unavailable 회귀
- analyzer warning 0, exact Dart formatting, Flutter full suite와 Web release build

## Manual and deferred verification

- owned hosted origin의 모든 deep route에 대한 SPA fallback/rewrite
- Chrome/Edge/Firefox/Safari direct load, refresh와 back/forward
- BFCache restore, stale tab, multi-tab logout와 account switch
- 실제 session expiry/revoke와 OAuth/OTP re-authentication
- 실제 account/household switch, membership removal와 forbidden race

## Security and privacy

- browser-visible `continue` 값은 `today|chores|calendar|family|settings|notifications|not-found|invite` 고정 집합이다.
- resource UUID, due date, invite token, callback fragment와 임의 query는 continuation에 포함하지 않는다.
- 상세 intent는 persistence하지 않고 같은 runtime의 expiry/revoke에만 사용할 수 있다.
- logout, identity 또는 household boundary를 넘는 상세 route 재사용을 금지한다.
- not-found와 forbidden을 같은 unavailable 표현으로 유지해 resource enumeration signal을 만들지 않는다.

## Rollback

- router의 transition hook과 recovery policy를 제거하고 기존 path-only in-memory intent로 되돌릴 수 있다.
- 내부 404 route를 제거하고 invalid dynamic route의 이전 상위 화면 fallback을 복구할 수 있다.
- DB/API/persisted state 변경이 없어 data rollback이나 migration은 필요 없다.

## Exit condition

- local implementation exit는 focused/full automation, analyzer, format와 Web release build가 모두 통과할 때 충족한다.
- FR-PLAT-011, NFR-WEB-004, T-WEB-02와 PDOD-055는 hosted SPA rewrite, 실제 browser history/BFCache와 real-account 전환 검증 전까지 `PARTIAL`이다.
