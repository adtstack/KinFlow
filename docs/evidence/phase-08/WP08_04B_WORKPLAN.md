# Phase 08 WP08-04B Capability Runtime Policy Workplan

## Status

- 상태: **LOCAL IMPLEMENTED / PARTIAL (2026-08-09)** — automated local gate 완료, WP08-04 전체와 G8 완료는 아님
- 수직 조각: exact capability policy → public sanitized rows → service-only versioned mutation/audit → explicit table classification → DB feature denial → strict Flutter snapshot → feature-family advisory guard → localized partial-read-only banner
- 요구사항: `FR-PLAT-004`, `NFR-COMP-01`, `D-031`, `D-042`, `CAP-018`, `T-REL-02`
- 계약: `docs/contracts/app-runtime-feature-policy.yaml.md`

## Product boundary

- 전역 update/read-only 정책은 최상위 비상 경계로 유지한다. 그 아래에서 household, chores, calendar, notifications, profile, billing mutation을 서로 독립적으로 중단할 수 있게 한다.
- feature policy는 이미 출시된 capability의 가용성 switch다. dev/prod Android의 여섯 row를 명시적으로 enabled seed해 기존 앱 동작을 보존한다.
- unknown/missing/duplicate feature는 enabled로 추측하지 않는다. 새 feature는 server seed, client enum, table mapping, contract/test review를 모두 추가해야 한다.
- feature가 disabled여도 해당 기능의 읽기와 다른 feature mutation, bounded offline cache, export/delete/legal/support/diagnostics는 유지한다.
- cohort, percentage, per-user/household override는 이번 수직 조각에 넣지 않는다. identity나 household가 policy payload/audit에 들어가는 것을 피하고 전체 기능 제어를 먼저 닫는다.

## Server and API design

1. `app_private.app_runtime_feature_policies`는 `(environment, platform, feature)`별 `mutations_enabled`, optimistic version과 timestamp를 가진다.
2. `app_private.app_runtime_feature_policy_events`는 correlation ID replay/mismatch와 immutable content-free audit를 제공한다.
3. `public.get_app_runtime_feature_policies`는 anon/authenticated에게 exact 6개 row를 feature 순으로 반환하고 private direct read를 거부한다.
4. `public.configure_app_runtime_feature_policy`는 service-role only, exact feature, expected version과 correlation ID를 요구한다.
5. 기존 30개 trigger를 explicit feature argument로 재분류한다. trigger argument가 없거나 unknown이면 stable unavailable error로 fail closed한다.
6. global update/read-only를 먼저 평가하고 feature disabled는 `KFR06`으로 거부한다. Edge는 이를 `CLIENT_FEATURE_DISABLED` 503 retryable로 privacy-safe mapping한다.
7. transaction cache는 global allowed와 exact feature allowed를 분리한다. 한 transaction에서 chores가 허용됐다는 이유로 disabled billing/calendar write가 우회되지 않아야 한다.
8. marker 없는 service/worker와 privacy/export/delete table 제외는 WP08-04A와 동일하게 유지한다.

## Flutter architecture

- domain: exact `AppRuntimeFeature`, feature policy invariant와 global+feature precedence를 가진 immutable snapshot.
- data: exact seven-key feature DTO와 exact six-row set validation. environment/platform mismatch, unknown, duplicate, missing, non-UTC, invalid version/timestamp는 전체 snapshot 실패다.
- infrastructure: 기존 Supabase data source가 global RPC와 feature rows RPC를 분리 호출하고 list/map outer shape를 엄격히 검증한다.
- application: 기존 controller single-flight와 last-good refresh preservation을 그대로 재사용한다.
- presentation: `Provider.family<bool, AppRuntimeFeature>`로 feature guard를 제공하고 모든 현재 mutation notifier를 exact feature에 연결한다.
- UX: global unavailable/update/read-only banner가 우선한다. global allowed이며 feature가 disabled된 경우 deterministic localized feature list와 retry를 표시하고 child/unrelated capability를 유지한다.

## Automated evidence plan

1. exact 12 compatibility-open seeds, table constraints, private grants와 6-row public read
2. service-only expected-version, correlation replay/mismatch, immutable feature audit와 rollback re-enable
3. six feature별 direct authenticated denial과 unrelated feature allow
4. Edge-forwarded user operation denial, markerless service/worker preservation
5. global update/read-only precedence와 global/per-feature transaction cache isolation
6. all 30 trigger exact table→feature arguments and privacy/export absence
7. domain exact enum/policy/snapshot precedence and immutable disabled set
8. DTO exact keys/types/UTC/scope, exact six unique rows, unknown/missing/duplicate failure
9. Supabase list outer shape and two RPC argument tests
10. family guard mapping for all mutation provider files; one disabled feature does not stop unrelated mutation providers
11. EN/KO/EN-XA feature labels/banner, retry, child preservation and compact 200% layout
12. focused/full DB, Edge/Node, Flutter, analyzer, format, codegen, schema lint, contract/matrix and whitespace gates

## Manual and deferred evidence

- hosted operator propagation, alert/dashboard, percentage/cohort rollout, N-1 signed binary, Play staged rollout, real accounts, multi-device와 physical-device는 마지막 통합 Gate로 미룬다.
- production policy를 변경하지 않는다. operator behavior는 local synthetic service-role RPC로만 검증한다.

## Rollback

- 운영 rollback은 exact feature를 expected version과 새 correlation ID로 다시 enable한다.
- 앱 rollback은 feature-family guard와 partial banner를 제거하되 DB classification/enforcement를 유지할 수 있다.
- DB rollback은 forward migration으로 모든 trigger를 WP08-04A global-only classification으로 먼저 복원한 뒤 feature RPC/audit/policy를 제거한다. 적용 migration은 수정하지 않는다.

## Non-scope

- arbitrary remote copy, URL, enum 또는 invariant 변경
- executable code/OTA update
- percentage, cohort, experiment, per-account/household targeting
- Store production mutation와 hosted/real-account/device evidence
- iOS/Web client policy adapter
