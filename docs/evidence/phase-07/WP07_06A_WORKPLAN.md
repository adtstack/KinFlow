# Phase 07 WP07-06A Profile and Regional Settings Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — WP07-06 전체와 G7 완료는 아님
- 시작일: 2026-08-08
- 완료일: 2026-08-08
- 수직 조각: authenticated load → profile/avatar/language/personal timezone edit → optional Owner/Admin household-timezone impact confirmation → atomic versioned save → immediate app locale refresh

## Requirements and decisions

- `FR-SET-001`: 본인 프로필은 최소 정보인 display name과 선택적 preset avatar만 편집한다.
- `FR-SET-002`: `en`/`ko` 언어와 유효 IANA 개인 시간대를 저장하고 성공 직후 앱 locale을 바꾼다.
- `FR-HH-002`: 가구 기본 시간대는 유효 IANA zone만 허용하고 변경 영향을 저장 전에 설명한다.
- `D-013`: Managed Child/profile 기능은 Store MVP에 노출하지 않으며 이 조각은 인증된 성인 본인 프로필만 다룬다.
- 반복 calendar/chore series는 생성 당시 저장된 timezone에 고정한다. 가구 시간대 변경으로 기존 local intent나 canonical instant를 재해석하지 않는다.

## Security and privacy boundary

- caller identity, active household, current membership role은 서버에서 `auth.uid()`로 다시 계산한다.
- 본인 profile만 수정할 수 있고 가구 시간대는 active Owner/Admin만 수정할 수 있다.
- display name은 trim 후 1~80자이고 control character를 거부한다. 법적 이름·이메일·생년월일은 요구하지 않는다.
- avatar는 앱 번들 preset key 또는 `null`만 허용한다. 업로드·외부 URL·원격 object key는 이 조각에서 받지 않는다.
- locale은 `en`/`ko`만, profile/household timezone은 PostgreSQL timezone catalog의 IANA zone만 허용한다.
- update는 profile과 household expected version을 검사하며 profile, 현재 active membership display/avatar, 선택적 household timezone을 한 transaction에서 갱신한다.
- 외부 Supabase payload는 exact record → repository mapper → domain 순서로 검증한다.

## Database and API impact

- authenticated-only `get_profile_preferences()` RPC는 본인 profile과 active household의 최소 설정 projection만 반환한다.
- authenticated-only `update_profile_preferences(...)` RPC는 profile expected version을 필수로 받고 household timezone을 바꿀 때만 household expected version을 요구한다.
- stable SQLSTATE: auth required, invalid input, profile/active household unavailable, forbidden household timezone, profile conflict, household conflict.
- profile display/avatar 변경은 동일 사용자의 active `household_members` row에 동기화한다.
- household timezone 변경은 private append-only audit에 actor, before/after zone, resulting version을 남긴다.
- direct table 권한은 확대하지 않으며 함수 execute만 `authenticated`에 부여한다.

## Flutter impact

- provider-independent domain entity/draft/failure/repository와 exact Supabase data source를 추가한다.
- controller는 load/save 중복 실행을 막고 optimistic conflict를 명시적으로 보여 주며 성공한 server projection만 화면과 locale에 적용한다.
- auth lifecycle host는 로그인/active-household 확정 시 preference를 load하고 로그아웃 시 system locale로 되돌린다.
- 설정 목록에 프로필 및 지역 설정 화면을 추가하고 display name, avatar preset, language, personal timezone을 편집한다.
- Owner/Admin에게만 household timezone editor와 반복 semantics 영향 confirmation을 노출한다. Member에게는 현재 기본값을 read-only로 표시한다.
- EN/KO/EN-XA, stable keys, scrollable 200% text layout을 검증한다.

## Automated evidence plan

- pgTAP: function grants, auth/profile/household availability, exact projection, IANA/locale/name/avatar validation, self-only update, member denial, Owner/Admin allowance, dual version conflicts, atomic rollback, membership sync, no-op version behavior, audit, existing series timezone preservation.
- Flutter: domain normalization, exact data parser/error mapping, repository mapping, controller load/save/conflict/double-submit/locale callback, auth lifecycle synchronization, settings route/widget role variants and 200% pseudo layout.
- focused tests 후 clean migration, DB lint/full pgTAP, Flutter analyzer/format/full regression, ARB/schema/matrix/secret/whitespace 검사를 실행한다.

## Manual and deferred evidence

- 실제 Google/Supabase 계정의 cross-device locale propagation, hosted PostgreSQL timezone catalog, Android process restart, 실제 기기 screen reader/keyboard는 사용자 요청대로 마지막 통합 Gate에서 검증한다.
- 사용자 이미지 업로드·crop/CDN lifecycle과 계정별 다중 active household는 이 조각에 포함하지 않는다.

## Rollback

- Flutter route/lifecycle host를 제거하면 기존 설정·핵심 기능은 유지된다.
- 신규 RPC execute를 revoke해 변경을 중단할 수 있으며 기존 profile/household row와 반복 series는 유지한다.
- migration은 forward-only다. 후속 migration에서 RPC를 대체하고 private audit은 보존한다.
