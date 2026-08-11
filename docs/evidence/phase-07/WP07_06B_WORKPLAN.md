# Phase 07 WP07-06B Searchable IANA Timezone Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-09)** — WP07-06 전체와 G7 완료는 아님
- 수직 조각: profile/household 현재 시간대 → 번들 IANA catalog load → 지역·도시 검색 → 명시적 선택 → 기존 atomic save/household impact confirmation

## Requirements and decisions

- `FR-SET-002`: 자유 입력 대신 검색 가능한 IANA 시간대 선택을 제공하고 선택값은 기존 저장 동작 전까지 로컬 draft로만 유지한다.
- `FR-HH-002`: active Owner/Admin의 가구 기본 시간대에도 같은 선택기를 재사용하며 Member의 read-only 경계는 유지한다.
- `D-013`: authenticated adult 범위만 유지하고 Managed Child surface는 추가하지 않는다.
- WP07-06A의 server-authoritative IANA 검증, expected-version atomic update, role 재계산, audit, 반복 series timezone/instant 보존 계약은 변경하지 않는다.

## Data and privacy boundary

- 앱에 이미 고정된 `timezone 0.11.1`의 IANA database `2025c`를 사용하며 catalog load/search에는 네트워크나 계정·가구 식별자가 필요하지 않다.
- `UTC`와 slash가 있는 IANA ID만 노출하고 `posix/`, `right/` namespace는 제외한다.
- 현재 UTC offset과 DST 여부는 선택을 돕는 load-time 표시값일 뿐 저장·반복 계산·권한 판단에 사용하지 않는다.
- 현재 server-authoritative 값이 bundle에 없더라도 화면에서 숨기거나 자동 변경하지 않는다.
- 검색어, 선택 이력, offset을 로그·분석·서버로 전송하지 않는다.

## Flutter impact

- provider-independent timezone catalog entity/search ranking/repository port를 추가한다.
- data implementation은 번들 database를 process당 한 번 초기화하고 exact identifier별 현재 offset/DST snapshot을 만든다.
- 개인/가구 시간대 입력을 read-only picker trigger로 바꾸고 검색 field, loading, retry, empty, selected state를 갖는 재사용 modal을 추가한다.
- 빈 검색은 현재 선택과 UTC를 먼저 보여 주고, 검색은 slash/underscore/대소문자를 정규화한 지역·도시 token으로 최대 100건을 결정적으로 정렬한다.
- catalog failure 시 기존 draft를 유지하고 retry만 제공하며 검증을 우회하는 자유 입력 fallback은 두지 않는다.
- EN/KO/EN-XA, 48dp target, labelled search, selected semantics, compact 200% scroll layout을 검증한다.

## Server and persistence impact

- 신규 migration, RPC, grant, RLS policy, storage 또는 remote payload는 추가하지 않는다.
- picker 선택은 기존 `update_profile_preferences(...)` 호출 전까지 저장되지 않는다.
- 실제 저장 시 PostgreSQL catalog의 `app_private.is_valid_iana_timezone`이 다시 검증하므로 번들 catalog를 authorization 또는 최종 유효성 authority로 취급하지 않는다.
- 가구 기본 시간대가 실제로 달라질 때의 영향 confirmation, role authorization, expected household version, private audit는 그대로 유지한다.

## Automated evidence plan

- domain: entry validation, duplicate rejection, query normalization/token AND, deterministic rank/limit, selected/UTC pinning.
- data: fixed instant에서 bundle initialization, UTC/대표 region 포함, offset/DST snapshot, forbidden namespace 제외, database version 고정.
- widget: personal/Owner picker open-search-select-save, Member read-only, load/retry/empty, current selection, no keyboard free text, household confirmation, EN/KO/EN-XA compact 200% overflow.
- regression: focused Flutter tests, analyzer, format, localization exact-key/pseudo checks, full Flutter suite, dependency/secret/matrix/whitespace gates.

## Manual and deferred evidence

- hosted PostgreSQL catalog와 bundle parity, 실제 계정·다중기기 저장, Android process restart, physical keyboard/TalkBack, DST·여행 실기기 표시는 사용자 지시대로 마지막 통합 Gate에서 검증한다.
- catalog version update/rollback 운영 훈련은 dependency update Gate에서 수행한다.

## Rollback

- picker trigger와 catalog provider를 제거해도 기존 profile save RPC와 저장 데이터는 유지된다.
- 필요 시 선택 field를 WP07-06A read-only/current-value 표시로 되돌리고 server mutation 기능을 유지할 수 있다.
- 번들 database version은 package lockfile과 함께 전진 업데이트하며 server schema rollback은 필요하지 않다.
