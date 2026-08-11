# Phase 10 WP10-01A Web Invite Sharing Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)**
- Vertical slice: Web adult invite creation result → explicit Web Share → unsupported/rejected state → separate explicit clipboard recovery
- Requirements: FR-HH-003, FR-HH-004, NFR-PRIV-01, NFR-WEB-001
- Capability: CAP-016
- Decisions: D-002, D-006, D-015, D-017, D-047, D-070
- Contract: `docs/contracts/web-invite-sharing.yaml.md`
- Test: T-LINK-03

## Product boundary

1. Web의 기존 성인 초대 생성 화면에서 사용자가 `Share link`를 누른 순간에만 `navigator.share`를 호출한다.
2. browser provider에는 localized title과 기존 `HouseholdInviteLink`가 검증한 canonical HTTPS URL만 전달한다.
3. 지원하지 않는 browser는 `unavailable`, 거부·취소·provider 오류는 raw detail 없는 `failed`로 축약한다.
4. 성공은 browser share Promise의 정상 종료만 뜻하며 recipient 전달, 열람 또는 초대 수락을 주장하지 않는다.
5. 실패 뒤 clipboard를 자동 변경하지 않는다. 기존 `Copy link`는 사용자의 별도 명시 동작과 write-only 경계를 유지한다.
6. Android는 기존 MethodChannel chooser를 그대로 사용하고 Web만 조건부 JS interop adapter를 선택한다.

## DB, API, dependency and storage impact

- PostgreSQL, RLS, RPC, Edge Function, remote DTO와 public configuration 변경 없음
- 새 runtime dependency, browser permission prompt, service worker, manifest와 application storage 변경 없음
- Flutter SDK의 `dart:js_interop`만 사용하며 Android native channel과 clipboard port 의미는 바꾸지 않음
- raw invite URL 수명은 기존 생성 화면 process memory와 사용자 gesture의 provider handoff 범위를 넘지 않음

## Implementation plan

1. 플랫폼 share factory를 native/Web conditional export로 분리한다.
2. injectable `WebShareClient`와 provider-neutral Web gateway를 두어 support, payload와 result mapping을 VM 테스트 가능하게 만든다.
3. Web-only browser client는 `navigator.share` 존재 여부를 먼저 확인하고 title/url 두 필드만 넘긴다.
4. 기존 controller의 single-flight, stable outcome, manual-copy recovery와 localized live region을 그대로 재사용한다.
5. pure adapter tests, native regression, composition source contract, analyzer와 production Web build를 통과시킨다.

## Automated verification

- exact validated URL과 localized title만 client로 전달
- unsupported client zero-call과 stable `unavailable`
- empty/oversized title의 provider-I/O 전 거부
- browser rejection의 raw token/provider detail 비노출
- native MethodChannel과 write-only clipboard 회귀
- conditional Web factory와 `navigator.share` source boundary
- exact Flutter analyzer, full suite, format와 Web prod release build

## Manual and deferred verification

- owned HTTPS origin의 `Permissions-Policy: web-share`와 iframe/embedding 정책
- Chrome, Edge, Firefox와 Safari의 지원, share target, cancel/back/resume
- 실제 성인 계정·recipient 전달·revoke/accept 경쟁과 verified App Link
- browser clipboard/history/storage forensic과 screen reader
- iOS native share

사용자 지시에 따라 위 live/browser/provider 검증은 마지막 Web 통합 Gate까지 미룬다.

## Security and privacy

- raw URL은 DB, cache, route query, log, analytics, error text와 새 controller state에 기록하지 않는다.
- browser client payload는 title/url allowlist이며 text, files, recipient와 provider metadata를 만들지 않는다.
- browser exception은 enum outcome으로 축약하고 UI에는 기존 localized 복구 문구만 보인다.
- share 실패가 clipboard mutation을 일으키지 않으며 copy는 항상 별도 user gesture다.

## Rollback

- Web factory만 unavailable gateway로 되돌려 Android chooser와 explicit clipboard fallback을 보존할 수 있다.
- 새 JS interop client와 Web gateway를 제거해도 DB/API/storage 정리나 migration rollback은 필요 없다.

## Exit condition

- local slice는 focused/full automation, analyzer, exact format와 production Web compilation이 통과하면 충족한다.
- CAP-016과 Web Household Gate는 actual browser, hosted policy, recipient와 real-account evidence 전까지 `PARTIAL`이다.
