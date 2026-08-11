# Phase 02 WP02-13 App-shell Session Resume Revalidation Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)**
- Phase: 02 only
- Vertical slice: root foreground lifecycle → authenticated session refresh → authoritative household re-resolution → fail-closed local isolation

## Requirements and decisions

- Requirements: `FR-AUTH-004`, `FR-AUTH-005`, `FR-AUTH-011`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`
- Decisions: `D-006`, `D-008`, `D-017`, `D-043`, `D-047`, `D-049`, `D-070`
- Contract: `docs/contracts/auth-session-resume-revalidation.yaml.md`
- Test IDs: `T-AUTH-01`, `T-AUTH-05`, `T-WEB-02`

## Scope

1. 인증 앱 셸 root 하나가 Android/Web foreground resume을 소유하고, 현재 보호 route가 허용된 세션만 repository refresh로 재검증한다.
2. 최초 mount는 기존 restore만 사용하며 중복 refresh를 만들지 않는다.
3. refresh 중 연속 resume은 동시에 호출하지 않고 최대 한 번의 trailing refresh로 합친다.
4. 같은 사용자 refresh도 active household를 다시 읽고, 이전과 다른 household 또는 no-household 결과는 household-bound local state를 purge/replace한 뒤에만 노출한다.
5. household load 실패 뒤 retry도 마지막으로 안전하게 해석된 private context와 비교해 전환 격리를 생략하지 않는다.
6. 만료·회수·부재·provider failure는 기존 full local purge와 route fail-close 계약을 재사용한다.

## DB / API / storage impact

- PostgreSQL migration, RLS, RPC, Edge Function, OpenAPI와 remote DTO: **변경 없음**
- 앱 persistent storage/schema: **변경 없음**
- runtime dependency, native permission, browser storage와 telemetry: **변경 없음**
- 기존 `AuthSessionRepository.refreshSession`과 active-household repository를 재사용한다.

## Security and privacy

- client는 token을 검사하거나 로그에 남기지 않고 provider-neutral session result만 소비한다.
- 새 household content는 transition purge/replace가 성공하기 전에는 protected route에 노출하지 않는다.
- purge 실패는 `localPurgeFailed` lock으로 유지하며 새 household나 이전 보호 화면을 표시하지 않는다.
- user/household/member/content identifier를 새 log, analytics, diagnostic payload에 추가하지 않는다.

## Automated verification

- root mount no-refresh와 authenticated/unauthenticated resume 분기
- duplicate resume single-flight 및 bounded trailing refresh
- expiration refresh의 full purge와 unauthenticated 전환
- same-user active household A→B, A→none, none→B 전환 purge
- household resolution failure→retry에서도 이전 private context 비교
- transition purge 실패의 locked fail-close
- focused auth controller/widget tests, auth/app regression, full Flutter regression
- analyzer fatal warnings, formatter, codegen/config/secret/architecture/whitespace Gate

## Manual and deferred verification

- hosted Supabase refresh/revocation, 실제 계정과 두 기기·다중 browser tab
- Web BFCache/stale tab, Android background/process termination과 network transition
- physical Android와 실제 browser session journey

사용자 지시에 따라 위 live 검증은 기능 개발 대부분이 끝난 뒤 마지막 통합 Gate까지 미룬다.

## Implemented result

- root lifecycle host는 최초 mount를 건드리지 않고 `resumed`에서만 보호 세션을 재검증한다.
- 동일 사용자·동일 household·동일 cache provenance 결과는 transient auth state를 발행하지 않아 화면별 resume refresh와 repository 구독을 중복 재시작하지 않는다.
- household drift, departure, account change, session expiration/revocation과 provider failure는 기존 purge·lock·route 경계를 재사용한다.
- focused auth 34건과 app-shell resume 통합 회귀 3건, 전체 Flutter 1,443건(+ live opt-in 1 skip), 통합 품질 Gate가 통과했다.
- 상세 실행 결과와 남은 live Gate는 `docs/evidence/phase-02/WP02_13_EVIDENCE.md`에 기록한다.

## Rollback

- 앱 root의 session lifecycle host를 제거하면 기존 initial restore와 명시적 refresh만 유지된다.
- controller의 private resolved-household context 추적을 되돌리면 기존 household resolution 동작으로 복귀한다.
- migration, stored-data cleanup과 provider configuration rollback은 필요 없다.
