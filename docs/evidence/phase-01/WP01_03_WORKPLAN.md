# Phase 01 WP01-03 Work Plan

- 작성일: 2026-07-24
- 기준 commit: `bd1f535`
- Work Package: WP01-03 Architecture Boundary
- 상태: COMPLETE

## Requirements

| ID | 구현 범위 |
|---|---|
| WP01-03 | domain/application/data/presentation sample slice, Riverpod override/DI, repository port/fake adapter, architecture import test, generated model drift test |
| D-006 | Riverpod은 의존성 조립과 presentation state에만 사용 |
| D-007 | data DTO는 Freezed/json_serializable을 사용하고 generated source를 커밋 |
| D-047 | domain/application은 Flutter, Riverpod, provider SDK와 독립 |
| FR-FLT-005 | build_runner 재생성 후 generated code diff 0 |
| SPEC-002 | repository port와 layer dependency direction을 자동 검사 |

## Sample Slice

- 제품 도메인을 선결정하지 않는 `features/foundation` 진단 슬라이스를 사용한다.
- domain은 value object, entity, stable failure, repository port를 소유한다.
- application은 repository port를 호출하는 use case만 소유한다.
- data는 local fixture datasource, generated DTO, mapper, repository adapter를 소유한다.
- presentation은 Riverpod provider와 화면 상태 매핑만 소유한다.
- 가구, 인증, 권한, 결제의 실제 동작으로 간주하지 않는다.

## Data / API Impact

- DB migration, RLS, RPC, Edge Function: 없음
- 외부 API/network call: 없음
- Supabase/Firebase/Google/RevenueCat SDK와 provider 설정: 없음
- local fixture에는 계정·가구·사용자 개인정보가 없음

## Dependency Plan

| Dependency | 확정 버전/license | 구분 | 목적 | 대안/선택 이유 | 플랫폼·권한·개인정보 | Rollback |
|---|---|---|---|---|---|---|
| `freezed_annotation` | 3.1.0 / MIT | runtime annotation | immutable DTO 선언 | 수기 equality/copyWith는 D-007과 drift 계약을 충족하지 못함 | Dart 전용, native permission·network·PII 없음 | DTO를 제거하고 dependency 제거 |
| `json_annotation` | 4.12.0 / BSD-3-Clause | runtime annotation | snake_case JSON 계약 선언 | 수기 parser는 D-007과 negative fixture 일관성이 낮음 | Dart 전용, native permission·network·PII 없음 | DTO를 제거하고 dependency 제거 |
| `build_runner` | 2.15.1 / BSD-3-Clause | dev | generator 실행 | generator 공통 실행기 | build/test 시에만 사용, 앱 runtime 영향 없음 | generated slice와 함께 제거 |
| `freezed` | 3.2.5 exact / MIT | dev | Freezed source 생성 | D-007 승인 기준, resolver의 prerelease 선택을 stable exact pin으로 차단 | build/test 시에만 사용, 앱 runtime 영향 없음 | generated slice와 함께 제거 |
| `json_serializable` | 6.14.0 / BSD-3-Clause | dev | JSON serializer 생성 | D-007 승인 기준 | build/test 시에만 사용, 앱 runtime 영향 없음 | generated slice와 함께 제거 |

Flutter SDK 3.44.7 / Dart 3.12.2 호환 버전을 package resolver로 확정하고 `pubspec.lock`에 고정한다. major upgrade나 Riverpod codegen 도입은 이 Work Package 범위가 아니다.

## Planned Tests

1. value object와 entity가 invalid state를 거부한다.
2. generated DTO가 snake_case JSON을 parse/serialize하고 invalid fixture를 거부한다.
3. mapper가 DTO를 domain entity로 변환하고 unknown status를 stable failure로 매핑한다.
4. repository adapter와 fake adapter가 동일 port 계약을 만족한다.
5. use case가 repository result를 그대로 조정한다.
6. Riverpod repository override가 presentation 결과를 교체한다.
7. architecture import test가 layer direction과 금지 SDK import를 검사한다.
8. build_runner 재생성 후 generated files와 lockfile diff가 0이다.
9. analyzer warning 0, 전체 test, dev/prod Android APK build를 통과한다.

## Non-scope

- Google/Supabase 로그인과 session lifecycle
- 실제 household/chore/calendar entity와 server contract
- Supabase local, migration, RLS, network datasource
- Riverpod generator와 app-wide state migration
- Phase 01 전체 Gate 또는 Phase 02 기능 완료 주장

## Rollback

- `features/foundation`, architecture 검사, generated source와 새 dependency를 함께 제거하면 `bd1f535`의 App Shell로 복귀한다.
- foundation home을 정적 shell 화면으로 되돌린다.
- DB/API/provider/사용자 데이터가 없어 data rollback은 없다.
