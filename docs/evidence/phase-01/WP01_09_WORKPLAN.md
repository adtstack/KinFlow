# Phase 01 WP01-09 Android Capability Self-Check and Recovery Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-09)** — `docs/evidence/phase-01/WP01_09_EVIDENCE.md`; 실제 settings/provider·실계정·실기기와 Web/iOS Gate는 미완료
- 수직 조각: exact capability snapshot → immutable recovery plan → local notification permission recheck → refreshed ordered recovery UI

## Requirements and completion boundary

- `FR-NOTIF-001`: 시스템 prompt를 임의로 띄우지 않고 사용자의 명시적 점검 동작으로 현재 알림 권한과 기존 기기 연결 상태를 다시 확인한다.
- `FR-PLAT-008`, `FR-PLAT-014`: exact five capability 상태를 준비됨·조치 필요·대안/제한으로 집계하고, 문제를 안정적인 우선순위로 정렬해 이유·대안·기존 복구 route를 제공한다.
- `NFR-PLAT-001`, `NFR-PLAT-002`: 계획 계산은 platform-free domain에 두고 실제 permission read는 기존 notification port만 사용한다.
- 완료 시 인증 사용자는 기존 `/settings/device-capabilities`에서 5개 상태 요약과 정렬된 복구 계획을 보고, 한 번의 명시적 action으로 로컬 알림 권한을 재확인한 뒤 즉시 갱신된 계획을 확인할 수 있다.

## Architecture and UX

- `PlatformCapabilityRecoveryPlan`은 available 항목을 준비됨으로 집계하고 `temporaryIssue → actionRequired → fallbackOnly → limited` 순서와 registry 순서 tie-break로 나머지를 정확히 한 번 materialize한다.
- 화면은 summary count, non-ready step, named fallback과 기존 notification/subscription/diagnostics route를 상세 카드보다 먼저 표시한다.
- 자체 점검은 `NotificationPushNotifier.refreshPermission()`만 호출한다. permission request, system settings, Store 또는 별도 provider health probe를 만들지 않는다. 권한 거부 시 endpoint 안전 정리, 허용 시 기존 binding 재조정처럼 필요한 network/persistence side effect는 이미 검증된 notification coordinator 내부에만 한정한다.
- 점검은 single-flight이며 완료/실패를 raw error 없이 localized live region으로 알린다. coordinator state 갱신은 기존 provider graph를 통해 registry snapshot과 recovery plan을 다시 계산한다.

## Security, privacy, and failure boundary

- 계획과 UI는 기존 enum-only snapshot만 소비하며 account, household, device, payment, configuration, credential, URI와 provider error를 추가하지 않는다.
- unavailable coordinator와 refresh 예외는 안정적인 로컬 실패 문구로 닫고 상태 상세는 기존 fallback을 유지한다.
- DB, migration, RPC, RLS, Edge Function, remote DTO, endpoint lifecycle, Store와 server entitlement 동작은 변경하지 않는다.

## Automated evidence plan

- domain: stable priority/order, exact summary partition, available exclusion, immutable steps, all-ready/limited/fallback/temporary/action variants.
- widget/provider: summary and ordered steps, single-flight refresh, success/failure live copy, notification state recomposition, existing safe route, KO와 EN-XA compact 200%/48dp.
- regression: platform registry, notification permission, route/settings, localization, architecture, analyzer, format, full Flutter, root contract/YAML/matrix/secret/whitespace gates.

## Manual and deferred evidence

- Android system settings에서 권한을 바꾼 뒤 복귀, 실제 Firebase/RevenueCat/Play/Keystore/browser/hosted health, 실계정·다중기기·실기기·TalkBack 검증은 사용자 지시에 따라 마지막 통합 Gate에 둔다.

## Rollback

- recovery plan entity/provider와 capability 화면의 self-check section만 제거하면 WP01-08의 read-only status 화면으로 돌아간다.
- schema/API/storage 변경이 없으므로 rollback migration, data backfill, provider 또는 계정 정리가 필요 없다.
