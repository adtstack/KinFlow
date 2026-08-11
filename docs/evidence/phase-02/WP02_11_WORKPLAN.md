# Phase 02 WP02-11 Privacy-safe Invite Sharing Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)**
- Phase: 02 only
- Vertical slice: one-time adult invite result → Android native share chooser → explicit clipboard recovery

## Requirements and decisions

- Requirements: `FR-HH-003`, `FR-HH-004`
- Capabilities: `CAP-002`, `CAP-016`
- Decisions: `D-002`, `D-006`, `D-015`, `D-017`, `D-047`
- Contract: `docs/contracts/invite-sharing.yaml.md`
- Test IDs: `T-LINK-02`, `T-LINK-03`, `T-I18N-01`, `T-A11Y-03`

## Scope

1. 기존 raw-once invite token으로 exact configured HTTPS `/invite/{token}` value object를 만들고 diagnostic string은 redacted로 유지한다.
2. 사용자가 명시적으로 공유를 누른 경우에만 Android `ACTION_SEND` `text/plain` chooser를 연다.
3. Android도 configured host, HTTPS, exact path/token과 query·fragment·userinfo·port 부재를 다시 검증한다.
4. native 성공은 전달·수락 완료가 아니라 공유 시트가 열린 상태로만 표현한다.
5. unavailable/provider failure는 stable localized 상태로 축약하고, 별도의 명시적 링크 복사 action을 복구 경로로 유지한다.
6. 링크·보조 코드 복사는 write-only provider-neutral port를 사용하고 실패·중복 action을 복구 가능한 상태로 처리한다.
7. clipboard retention 안내, live-region 결과, EN/KO/EN-XA와 compact 200% text를 제공한다.

## DB/API/storage impact

- PostgreSQL migration, RLS, RPC, Edge Function, OpenAPI, remote DTO: **변경 없음**
- local persistent storage와 schema: **변경 없음**
- Android permission: **변경 없음**
- 새 runtime dependency 또는 provider SDK: **변경 없음**
- raw token lifecycle: 기존 invite creation 화면의 process memory 범위를 확장하지 않음

## Security and privacy

- raw token/link/code를 log, analytics, DB, cache, route query, error 또는 controller state에 저장하지 않는다.
- 공유와 복사는 각각 사용자 gesture 뒤에만 수행하고 share failure 뒤 자동 복사는 금지한다.
- native와 Dart 양쪽에서 share URL을 검증하며 임의 URL, custom scheme, query/fragment/userinfo/port를 거부한다.
- native/provider exception과 설치 앱 목록은 UI·log에 노출하지 않는다.
- 공유 시트가 열렸다는 사실만 알리고 실제 recipient 선택·전송·수락을 성공으로 추정하지 않는다.

## Automated verification

- invite link exact construction, invalid host 거부와 diagnostic redaction
- MethodChannel exact method/argument, invalid link 선차단, opened/unavailable/failure mapping
- clipboard exact explicit write, no read, provider exception mapping
- application controller single-flight와 raw credential-free state
- share-opened, unavailable/failure → manual copy recovery, copy failure/retry widget flows
- share/revoke concurrency guard, EN/KO/EN-XA, 320×568 200% text와 48dp action
- existing create/revoke, token scrub, account switch, route and invite tests regression
- analyzer fatal warnings, format, codegen drift, localization, architecture, config, secret and documentation gates
- Android Kotlin compilation/source contract without launching a physical share sheet

## Manual and deferred verification

- 실제 Android share-sheet의 앱 목록, cancel/back/resume와 OEM 차이
- 실제 recipient 전달 뒤 owned-domain verified App Link cold/warm open
- 실제 계정·다중기기·실기기와 clipboard/keyboard forensic
- iOS native share implementation

사용자 지시에 따라 위 live 검증은 마지막 통합 Gate까지 미룬다. 이 WP는 local 기능을 테스트 가능한 상태로 만들되 `CAP-002`, `CAP-016`의 전 플랫폼 완료를 주장하지 않는다.

## Rollback

- Dart share controller/port/provider와 Android MethodChannel handler를 제거하면 기존 invite creation/revoke 흐름으로 돌아간다.
- 명시적 clipboard copy는 독립 fallback으로 유지할 수 있다.
- DB/API/storage/dependency/permission 변경이 없으므로 migration, data cleanup 또는 provider rollback은 필요 없다.
