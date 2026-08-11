# Phase 01 WP01-10 Privacy-safe Analytics Governance Workplan

## Status

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)** — `docs/evidence/phase-01/WP01_10_EVIDENCE.md`; live/provider Gate deferred
- 수직 조각: Settings entry → versioned device preference → typed event gate → unavailable production sink → SDK/privacy inventory
- 요구사항: `FR-PLAT-001`, `FR-PLAT-002`, `FR-PLAT-003`, `NFR-PRIV-01`, `NFR-OBS-01`
- 완료 증거: `docs/evidence/phase-01/WP01_10_EVIDENCE.md`

## Product boundary

- 인증된 성인 사용자가 Settings에서 optional usage analytics 기본 OFF 상태, 현재 collection 가능 여부, exact event boundary, Managed Child 차단 정책과 데이터 처리 SDK inventory를 확인하고 기기 설정을 변경한다.
- 설정은 법적 동의 기록이 아니라 `analytics-usage-v1` 범위의 device/environment-local preference다. 공급자·수집 필드·목적·정책 버전이 확대되면 기존 허용은 유효하지 않으며 다시 OFF가 된다.
- 현재 production composition에는 외부 behavioral analytics sink가 없다. 허용을 저장해도 승인된 sink가 없는 동안 이벤트는 전송되지 않으며 화면이 이를 명확히 표시한다.
- Sentry는 기존 privacy-filtered operational error reporter로만 유지하고 optional usage analytics sink로 재사용하지 않는다.

## Exact event and dispatch boundary

- 호출자는 arbitrary string/map 대신 exact six-value event enum만 전달한다.
- sink envelope는 `event_name`, `event_version`, `platform`, `app_release`, `environment`의 exact 5개 public/content-free field만 가진다.
- WP01-10은 identifier, pseudonymous ID, request ID, locale/timezone, role, result attribute와 family content를 모두 생략한다.
- dispatch는 `Managed Child block → granted preference → sink available → best-effort emit` 순서다. child mode는 preference storage나 sink를 호출하기 전에 닫힌다.
- sink unavailable/throw는 stable local result로 축약하며 로그인, navigation, mutation 또는 bootstrap을 실패시키지 않는다.
- 실제 앱 연결은 authenticated entry마다 `application.session.started`를 최대 한 번 dispatch하는 lifecycle host다. scope key나 auth/household 값은 envelope로 전달하지 않는다.

## Storage, security, and privacy

- 전용 `flutter_secure_storage` namespace에 exact key/value 하나만 저장하고 account, user, household, member, device ID나 timestamp는 저장하지 않는다.
- missing/stale/malformed/read failure는 모두 withdrawn으로 fail closed한다. save failure는 기존 persisted preference를 바꾸지 않고 stable UI failure만 표시한다.
- 이 설정은 비식별 device preference이므로 logout/account switch purge 대상이 아니며 별도 namespace로 auth/cache/token과 격리한다.
- DB migration, RLS, RPC, Edge/API, remote DTO, server consent record, 새 dependency·permission·network client는 추가하지 않는다.

## UI and accessibility

- `/settings/analytics-privacy` route와 Settings 도움말 tile을 추가한다.
- 화면은 optional preference/status, allowlist boundary, child-mode block, Sentry/Firebase/RevenueCat/Google+Supabase 목적별 inventory와 절대 수집하지 않는 범위를 표시한다.
- load/save/retry는 single-flight이고 raw storage/provider error를 노출하지 않는다.
- EN/KO/EN-XA, 320×568 200% text, scroll, semantics live status와 48dp action을 검증한다.

## Automated evidence plan

1. exact six event names, version and exact five-field envelope
2. child-first gate, default/withdrawn/stale/malformed/read failure, unavailable/throw isolation and successful fake sink
3. secure repository exact namespace key/value and failed-write preservation
4. controller load/save/retry/single-flight and stable failure
5. settings tile/route, preference/status, inventory, no raw content, KO/EN-XA compact 200%
6. pubspec exact direct dependency inventory and forbidden analytics/ads/tracking package absence
7. lifecycle authenticated-entry dedupe and no identity/content envelope
8. focused/impact/full Flutter, analyzer, format, codegen, root CI, YAML/CSV/ARB/secret/whitespace gates

## Manual and deferred evidence

- approved hosted analytics sink, dashboard metrics, retention/region/access/deletion, final legal basis and server consent record
- Sentry/project SDK console inventory, actual Managed Child runtime, real account/multi-device/physical-device
- iOS/Web composition, TalkBack/VoiceOver and signed Store disclosure review

사용자 지시에 따라 위 live/provider 검증은 마지막 통합 Gate까지 미룬다.

## Rollback

- analytics route/tile/lifecycle host, providers/domain/data/composition과 전용 secure preference namespace를 제거하면 기존 no-behavioral-analytics 상태로 돌아간다.
- DB/API/remote provider가 바뀌지 않으므로 migration, backfill, remote event 또는 account cleanup은 없다.
