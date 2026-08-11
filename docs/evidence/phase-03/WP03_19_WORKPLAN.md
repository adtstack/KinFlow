# Phase 03 WP03-19 Searchable Internal Chore Template Library Workplan

## Status

- **LOCAL AUTOMATED COMPLETE (2026-08-09)** — Phase 03/P1 activation and live validation are not complete
- Phase: 03 only
- Vertical slice: app-bundled template catalog → localized category/search discovery → editable one-time or guided draft → existing create contracts
- Release boundary: P1 local implementation; production activation and live validation are not claimed

## Requirements and decisions

- Requirements: `FR-CHORE-010`, `FR-CHORE-001`, `FR-CHORE-002`, `NFR-PRIV-01`, `NFR-A11Y-01`, `NFR-I18N-01`
- Decisions: `D-002`, `D-013`, `D-017`, `D-036`, `D-047`, `D-054`, `D-058`
- Contract: `docs/contracts/chore-templates.yaml.md` version `2026-08-09-wp03-19`
- Test ID: `T-CHORE-TEMPLATE-LIBRARY`

## Product and domain boundary

1. 기존 6개 entry를 stable key·상대 순서와 함께 보존하고 generic household chore 10개를 추가해 exact 16개 catalog를 만든다.
2. 각 entry는 exact category 5개 중 하나와 daily/weekly 추천 cadence만 가진다. domain에는 localized/free-form 문자열, household/user/member 식별자, 날짜, 장소 또는 원격 content가 없다.
3. one-time/repeating 생성과 first-household guided exact-three 흐름에서 같은 browser를 사용한다. 초기값은 전체 category와 빈 query다.
4. category와 query는 교집합으로 적용하고 query는 현재 locale의 표시 title에 대해 trim·case-insensitive contains로만 비교한다. 결과가 없으면 명시적 localized empty state를 표시한다.
5. filter로 가려져도 선택과 편집 draft는 보존한다. template 적용은 기존처럼 localized title과 추천 cadence만 바꾸며 assignee/date/time/description은 건드리지 않는다.

## Database, API, persistence and privacy

- migration, seed, RPC/Edge, RLS, runtime dependency, native permission과 public config를 추가하지 않는다.
- `CreateOneTimeChoreRequest`, `CreateRecurringChoreRequest`, guided resume exact payload를 변경하지 않는다.
- query, category, selected key, catalog version과 사용 순서는 process memory 밖으로 저장·전송·기록하지 않는다.
- template metadata나 localized label에 대한 log/analytics/recently-used/ranking을 추가하지 않는다.
- server-managed/household-specific catalog, remote image/content, recommendation, personalization과 marketplace는 별도 결정 전 범위 밖이다.

## UI, accessibility and localization

- EN/KO/EN-XA ARB만 사용해 search label/clear action/category/empty state와 10개 title을 제공한다.
- search field와 category/template chips는 명시적 stable key를 가지며 모든 action은 최소 48dp Material target을 유지한다.
- one-time은 single-select `ChoiceChip`, guided는 exact-three multi-select `FilterChip` semantics를 유지한다.
- 320×568, 200% text에서 전체 form scroll과 filter/search empty/clear 흐름에 overflow가 없어야 한다.

## Automated evidence plan

1. exact version/order/count, unique safe key, category coverage와 exact parser rejection
2. domain의 Flutter/Riverpod/provider SDK 및 localized/free-form content 부재
3. reusable browser의 category/query intersection, case-insensitive search, no-results, clear와 hidden-selection preservation
4. one-time에서 새 daily/weekly template 적용, 직접 편집, request metadata 비확장 회귀
5. guided에서 검색/분류 후 exact-three 선택, selection limit, review·submit ordering과 secure resume 회귀
6. EN/KO/EN-XA exact coverage, KO 검색, pseudo 200% compact scroll, 48dp target
7. focused/full Flutter, analyzer, formatter, codegen, public config, secret, docs/matrix와 whitespace Gate

## Stop conditions and rollback

- template metadata가 request/cache/log/analytics에 들어가거나 identity/household content가 catalog에 포함되면 중단한다.
- filtering이 선택·draft를 삭제하거나 기존 direct-create/guided resume를 깨뜨리면 중단한다.
- localization 누락, inaccessible search/clear/category state, 200% overflow 또는 48dp 미만 action이 있으면 완료하지 않는다.
- rollback은 reusable browser, 추가 enum/ARB, D-058·contract successor와 해당 tests/docs만 제거한다. 기존 6-entry WP03-08 catalog와 create/guided contracts로 되돌릴 수 있고 DB/data cleanup은 없다.

## Deferred validation

- 실제 계정·remote Supabase·다중기기·Android 물리 기기 keyboard/TalkBack/font scale
- 실제 household의 catalog 적합성, 분류명·검색성·활성화 영향에 대한 사용자 연구
- remote catalog, 추천/개인화, recently used, ranking, analytics와 marketplace
