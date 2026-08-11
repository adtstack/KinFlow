# Phase 01 WP01-08 Android Platform Capability Registry Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-09)** — `docs/evidence/phase-01/WP01_08_EVIDENCE.md`; 실제 provider·실기기와 Web/iOS Gate는 미완료
- 수직 조각: production dependency composition → exact five-capability registry → local notification-state resolution → Settings device capability status → existing safe fallback routes

## Requirements and completion boundary

- `FR-PLAT-008`: 알림, Store 결제, 암호화 로컬 저장소, 외부 링크, background delivery의 선택 provider와 지원 상태를 한 registry에서 관리한다.
- `FR-PLAT-014`: 미구성, 권한 미결정·거부, runtime unavailable, 일시 실패, 의도된 client limitation을 조용히 숨기지 않고 이유와 대안을 표시한다.
- `NFR-PLAT-001`, `NFR-PLAT-002`: provider SDK와 Flutter는 domain 모델 밖에 유지하며 기존 port/fallback 조립을 변경하지 않는다.
- 완료 시 인증 사용자가 `/settings/device-capabilities`에서 exact 5개 항목과 선택 provider, 상태, fallback을 확인하고 기존 알림·구독·진단 화면으로 이동할 수 있다.

## Architecture and UX

- platform-free domain registry가 exact ID/order, provider/fallback enum과 deterministic 상태 해석을 소유한다.
- `AuthDependencies` production/unavailable composition이 실제로 조립된 billing port, push coordinator, Android encrypted read cache, URI launcher의 boolean 결과만 registry에 전달한다. UI는 SDK type이나 public configuration을 검사하지 않는다.
- presentation provider는 기존 in-process `NotificationPushState`를 제한된 notification signal로 변환해 registry snapshot과 합성한다. registry screen은 refresh, permission request, network, Store 또는 persistence 호출을 만들지 않는다.
- Settings의 새 tile과 별도 scrollable screen은 상태를 색상만이 아니라 localized text/icon으로 표시하고, 문제가 있는 항목에만 기존 notification center, subscription settings 또는 diagnostics route를 대안으로 제공한다.
- 이 registry는 WP08 runtime mutation policy와 별개다. 서버 kill switch, minimum build, provider 원격 health를 판단하거나 변경하지 않는다.

## Security, privacy, and failure boundary

- configuration key/value, Firebase·RevenueCat credential, URI, raw provider exception, 계정·가구·기기·결제 식별자를 snapshot/UI/log에 포함하지 않는다.
- configuration/bootstrap 실패 composition은 exact five-entry fail-closed registry를 사용한다. unknown/duplicate capability나 임의 provider string을 허용하지 않는다.
- 알림 adapter가 없거나 권한이 거부되어도 durable in-app inbox를 대안으로 표시하고, billing adapter가 없으면 server entitlement read-only 경계를 유지한다.
- DB, migration, RPC, RLS, Edge Function, remote DTO와 기존 provider lifecycle은 변경하지 않는다.

## Automated evidence plan

- domain: exact ID/order, every notification state, fixed capability availability/fallback/action, immutable snapshot.
- composition: concrete/injected adapter availability와 unavailable bootstrap이 registry에 정확히 반영됨을 검증한다.
- widget: five rows, provider/reason/fallback copy, dynamic attention states, safe route actions, Korean, EN-XA compact 200% and 48dp.
- router/settings: protected nested route와 tile navigation을 검증한다.
- focused suites 후 architecture/localization, analyzer, format, full Flutter, root contract/YAML/matrix/secret/whitespace gates를 실행한다.

## Manual and deferred evidence

- 실제 Android notification permission/system settings, Firebase, RevenueCat/Play, Keystore process restart, browser/chooser, hosted server fallback, 실계정·다중기기·실기기 검증은 사용자 지시대로 마지막 통합 Gate에 둔다.

## Rollback

- registry field/provider, Settings tile/route/screen을 제거해도 기존 notification, billing, secure cache, URL launcher, background handler와 stored/server data 계약은 변하지 않는다.
- schema/API/storage mutation이 없으므로 rollback migration이나 data backfill이 필요 없다.
