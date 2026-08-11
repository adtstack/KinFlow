# Phase 08 WP08-04A Server-authoritative Runtime Policy Workplan

## Status

- 상태: **LOCAL IMPLEMENTED / PARTIAL (2026-08-09)** — WP08-04 전체와 G8 완료는 아님
- 수직 조각: versioned server policy → public sanitized read → installed-build evaluation → app-wide read-only/update banner → client advisory mutation stop → database-authoritative mutation denial
- 요구사항: `FR-PLAT-004`, `FR-PLAT-005`, `NFR-COMP-01`, `D-030`, `D-031`, `D-042`, `CAP-018`, `T-REL-02`
- 계약: `docs/contracts/app-runtime-policy.yaml.md`

## Product boundary

- Store binary를 OTA code로 바꾸지 않고 서버 정책으로 긴급 read-only mode와 최소 지원 Android build/contract 범위를 배포한다.
- 강제 업데이트는 emergency에만 사용한다. 호환 범위를 벗어난 앱에서도 로그인/session, 읽기, bounded offline cache, 개인·가구 export, 계정·가구 삭제, legal/support/diagnostics 접근은 가능한 범위에서 유지한다.
- 앱 배너는 사용자에게 상태와 재시도/Play Store 이동을 제공하지만 권한 경계가 아니다. 실제 non-privacy mutation은 database trigger가 요청 시점에 다시 검사한다.
- policy fetch 장애는 오프라인 읽기 전체를 막지 않는다. 알려진 제한 상태에서 client mutation notifier는 provider/network I/O 전에 중단하고, 정책을 알 수 없는 온라인 mutation은 서버가 권위 있게 허용하거나 stable error로 거부한다.

## Server and API design

1. `app_private.app_runtime_policies`는 `(environment, platform)`별 최소 version/build, optional contract 범위, `mutations_enabled`, optimistic version과 server timestamp를 가진다.
2. dev/prod Android row는 update gate 비활성·mutation 허용으로 seed한다. 새 feature flag의 안전한 기본값은 기존 capability를 추측해 켜지 않는 것이 원칙이지만, 이 global kill switch는 기존 앱 호환을 위해 명시적으로 허용 상태로 시작한다.
3. `public.get_app_runtime_policy`는 anon/authenticated가 읽을 수 있는 exact content-free projection이며 private table 직접 접근은 모두 거부한다.
4. `public.configure_app_runtime_policy`는 service-role only, expected-version, correlation-id replay/mismatch 검증, immutable content-free audit를 적용한다.
5. authenticated client가 직접 쓰거나 Edge runtime이 allowlisted compatibility header와 전용 user-operation marker를 붙여 service RPC로 전달하는 product aggregate table에는 before-row trigger를 설치한다. marker 없는 service/worker와 privacy/export tables는 제외한다.
6. header가 없는 N-1 앱은 prod/android/build 0/contract unknown으로 처리한다. 기본 정책에서는 계속 동작하지만 emergency minimum 또는 contract range가 설정되면 mutation이 차단된다.
7. SQLSTATE는 `KFR01` update required, `KFR02` mutations disabled, `KFR03` policy unavailable로 고정한다. 오류 메시지는 stable copy이며 raw request/header 값은 포함하지 않는다.

## Flutter architecture

- domain: runtime client identity, exact policy invariant, build/contract comparison과 allowed/read-only/update-required pure decision.
- application: repository-neutral single-flight load/refresh controller. 기존 snapshot이 있으면 refresh failure 시 보존한다.
- data: exact ten-key DTO/mapper, provider repository, unavailable fallback.
- infrastructure: Supabase RPC adapter, package-info installed build reader, fixed Play Store URL launcher, Supabase global compatibility headers.
- composition: auth runtime이 만든 하나의 Supabase client를 공유하고 bootstrap에서 repository/build-reader/launcher provider를 override한다.
- presentation: initial/resume lifecycle host와 app-wide localized banner. known restriction에서는 mutation notifier가 provider/network/store I/O 전에 반환한다. privacy/export/delete notifiers는 의도적으로 gate하지 않는다.

## Dependency and privacy review

- 새 package는 추가하지 않는다. 기존 exact `supabase_flutter`, `package_info_plus`, `url_launcher`만 adapter 뒤에서 재사용한다.
- policy payload와 audit에는 user/household/member/content/provider/token/free-form reason/URL이 없다.
- Play URL은 서버 payload가 아니라 validated application ID로 고정 생성한다.
- compatibility header는 authorization이 아니다. RLS, role, expected version, idempotency와 domain invariant는 그대로 유지한다.
- structured log는 stable capability/operation/result/reason만 사용하고 version/header/payload/raw exception을 기록하지 않는다.

## Automated evidence plan

1. policy table constraints, seeded defaults, exact grants, sanitized anon/auth read와 direct-access denial
2. service-only optimistic/idempotent config, correlation mismatch, rollback lowering, immutable audit
3. authenticated insert/update/delete denial for build/contract/kill-switch and service/privacy/export preservation
4. missing N-1 header behavior, malformed/unknown header stable denial, transaction-local evaluation cache
5. domain identity/policy validation and build/contract/precedence decision matrix
6. DTO exact key/type/UTC/environment/platform correlation and provider failure mapping
7. Supabase adapter RPC parameters and global client header composition
8. controller single-flight, retry, resume refresh, last-good snapshot preservation
9. EN/KO/EN-XA banner, retry/update action, compact 200% layout, cached-read child preservation
10. representative chore/calendar/household/notification/profile/billing mutation notifiers stop before I/O while export/delete remain callable
11. focused/full DB and Flutter regression, analyzer, format, codegen, Node/workflow, public config, secret scan, schema lint and whitespace gate

## Manual and deferred evidence

- 실제 Play Store listing/update handoff, staged rollout pause, hosted dev/prod policy propagation, N-1 signed binary와 physical-device foreground resume는 마지막 실계정·실기기 Gate로 미룬다.
- service-role operator runbook은 local synthetic RPC로 검증한다. production policy 변경은 이번 기능 개발 단계에서 수행하지 않는다.

## Rollback

- 운영 rollback은 새 version/correlation ID로 `mutations_enabled=true`, 낮은 minimum build 또는 넓은 contract range를 배포한다.
- 앱 rollback은 lifecycle/banner와 advisory notifier guard를 제거하되 server trigger를 유지하면 구버전 앱도 정책에 따라 보호된다.
- DB rollback이 필요하면 forward migration으로 protected table trigger를 먼저 제거한 뒤 public RPC/private audit/policy 순서로 제거한다. 적용 migration은 수정하지 않는다.

## Non-scope

- OTA/runtime executable code download
- arbitrary remote copy/URL/invariant changes
- feature별 세분화된 rollout rules나 cohort targeting
- Store production rollout mutation
- iOS/Web policy UI와 actual multi-device/N-1 rehearsal
