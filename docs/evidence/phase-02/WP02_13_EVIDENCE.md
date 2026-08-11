# Phase 02 WP02-13 App-shell Session Resume Revalidation Evidence

## Result

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)**
- 기준 commit: base `a85f262`; implementation은 현재 연속 workspace
- 환경: macOS arm64, Flutter SDK 3.44.7 stable, Dart 3.12.2, Node 24.15.0
- 완료 경계: 로컬 기능·통합·품질 자동 검증은 통과했다. hosted Supabase, 실계정, 다중 tab/device, Android process lifecycle, Web BFCache와 실기기 검증은 사용자 지시에 따라 마지막 통합 Gate로 보류한다.

## 1. 구현한 요구사항 ID

| ID | 로컬 결과 | Evidence |
|---|---|---|
| FR-AUTH-004 / T-AUTH-05 | PASS FOR LOCAL FEATURE SLICE / OVERALL IN PROGRESS | root foreground resume가 provider session을 재검증하고 만료·회수·부재·provider failure를 기존 purge 및 route 경계로 전달한다. |
| FR-AUTH-005 | PASS FOR LOCAL PURGE HANDOFF / OVERALL IN PROGRESS | session loss와 account switch는 full sensitive-state purge를 완료한 뒤에만 protected route를 닫는다. |
| FR-AUTH-011 | PASS FOR LOCAL AND WEB-COMPILED APP SHELL / OVERALL PARTIAL | navigation과 initial mount가 아닌 root resume만 소유하며 Web 동일 코드 경계에서 동작한다. 실제 BFCache·다중 tab은 보류했다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW LOCAL SURFACE | authoritative household drift는 household-bound state를 먼저 purge/replace하며 token, identifier, content와 raw provider error를 새 저장·로그·분석 payload에 추가하지 않는다. |
| NFR-REL-01 | PASS FOR LOCAL CONCURRENCY CONTRACT | 동시에 하나만 실행하고 flight 중 resume burst는 최대 한 번의 trailing refresh로 합친다. |

## 2. 변경 파일과 migration

- 계약·계획: `docs/contracts/auth-session-resume-revalidation.yaml.md`, contract index, `docs/evidence/phase-02/WP02_13_WORKPLAN.md`
- 앱 root: `apps/kinflow_app/lib/app/app.dart`
- auth application/composition: `auth_lifecycle_controller.dart`, `auth_providers.dart`
- lifecycle owner: `auth_session_lifecycle_host.dart`
- 자동 검증: auth controller/widget tests와 기존 Chore target, Today Chores, Notification Center resume harness
- governance: Phase 02, requirements/test traceability, changelog와 이 evidence
- PostgreSQL migration, RLS, RPC, Edge Function, OpenAPI, persistent schema, runtime dependency와 native permission: **변경 없음**

## 3. 자동 테스트와 결과

| 검증 | 결과 |
|---|---|
| focused auth controller + lifecycle widget | **34 passed, 0 failed** |
| 기존 화면 resume 통합 회귀 | **3 passed, 0 failed** — occurrence target, stale Today Chores, shared notification inbox |
| Flutter full regression | **1,443 passed, 1 explicit local-Supabase opt-in skipped, 0 failed** |
| Flutter analyzer | **0 issues** with fatal infos/warnings |
| repository Node contract | **157 passed, 0 failed** |
| workflow/action lint | **PASS** — 6 jobs, 22 pinned action uses |
| formatter | **742 files checked, 0 changed** |
| public config / secret scan | **PASS / 0 high-confidence findings** |
| generated code drift | **8 files checked, 0 outputs** |
| coverage | **30,434 / 37,922 lines, 80.25%** |
| documentation structure | **PASS** — 445 Markdown files have balanced fences; 13 matrices are rectangular with declared counts; requirements 127×18, tests 100×11; WP02-13 YAML parses |

초기 full regression은 기존 세 resume 화면이 fake repository의 기본 `session absent` 응답으로 닫히는 문제를 정확히 포착했다. fake session을 정상 refresh로 명시한 뒤에도 transient `AuthRefreshing → Active`가 화면 repository를 중복 재시작하는 실제 통합 문제가 드러나, resume 전용 무중단 revalidation으로 분리했다. 최종 focused, integration, full suite와 quality Gate는 모두 통과했다.

## 4. 실제 기기·sandbox 수동 검증

- hosted Supabase session refresh/revoke, 실제 계정, 실제 mailbox와 Store/provider 계정: **NOT RUN**
- Android background/process termination/network transition, Web history/BFCache와 다중 tab: **NOT RUN**
- 두 성인 계정·다중 기기 account/household drift, physical Android/browser: **NOT RUN**
- 이 WP에는 새 DB/API가 없어 local Supabase reset이나 mutation probe를 실행하지 않았다.

## 5. 보안·개인정보 영향

1. client token inspection은 추가하지 않고 기존 provider-neutral `refreshSession` 결과만 소비한다.
2. 새 user/household/member/content 식별자, token, provider message, log, analytics와 diagnostic attribute를 만들지 않았다.
3. household A→B, A→none, none→B는 old household-bound state의 purge/replace 성공 전에는 새 context를 발행하지 않는다.
4. transition purge 실패는 `localPurgeFailed` lock으로 끝나며 이전 또는 새 protected content를 노출하지 않는다.
5. 동일 사용자·household·cache provenance 성공은 transient auth state를 발행하지 않아 unrelated feature subscription과 content fetch를 불필요하게 재시작하지 않는다. cache provenance가 바뀌면 stale/fresh 상태 갱신을 위해 새 protected context를 발행한다.

## 6. 남은 위험·OPEN 결정

- Supabase SDK의 실제 `tokenRefreshed`, revoke propagation 순서와 네트워크 복구는 hosted session에서 확인해야 한다.
- Web BFCache와 여러 tab의 resume 이벤트 순서, Android process recreation과 rapid lifecycle event는 실제 platform에서 검증해야 한다.
- physical-device timing과 두 계정·두 기기 household drift의 server propagation window는 아직 측정하지 않았다.
- 새 OPEN 제품 결정은 없다. iOS는 D-002/ADR-0002에 따라 계속 후속 범위다.

## 7. Rollback 방법

- `KinFlowApp` root에서 `AuthSessionLifecycleHost`를 제거하면 initial restore와 기존 명시적 refresh만 남는다.
- notifier/controller의 `revalidateOnResume`과 private resolved-household context 추적을 되돌리면 기존 auth lifecycle로 복귀한다.
- DB, API, persistent schema와 stored-data backfill이 없어 migration rollback이나 device data migration은 필요 없다.

## 8. 다음 Work Package 진입 조건

- focused 34건, resume integration 3건, full Flutter 1,443건, fatal analyzer와 repository quality Gate가 green일 것: **충족**
- Phase 02 전체 Exit Gate를 완료로 바꾸지 않고 live/real-account evidence를 마지막 통합 Gate에 남길 것: **충족**
- 따라서 다음 미구현 기능 Work Package에 진입할 수 있다. 실계정 테스트는 사용자 지시에 따라 계속 마지막에 수행한다.
