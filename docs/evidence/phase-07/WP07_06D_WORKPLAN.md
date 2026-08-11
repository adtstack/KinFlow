# Phase 07 WP07-06D Regional Date/Time Preview Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-09)** — `docs/evidence/phase-07/WP07_06D_EVIDENCE.md`, WP07-06 전체와 G7 완료는 아님
- 수직 조각: profile regional draft → bundled catalog exact lookup → same-instant personal/household wall time → draft-locale formatting → explicit refresh/retry → unchanged save command

## Requirements and completion boundary

- `FR-SET-002`: 저장 전에 언어·개인 시간대 선택이 날짜와 시간 표시에 미치는 결과를 확인한다.
- `FR-PLAT-001`, `NFR-I18N-01`: EN/KO Material date/time 형식과 system 12/24-hour preference를 사용하고 EN-XA 200% layout을 유지한다.
- 완료 시 profile regional card에서 개인과 active household의 현재 시각을 같은 UTC instant 기준으로 비교하고, draft 언어 또는 시간대 선택 직후 저장 없이 결과가 바뀐다.

## Architecture and UX

- app 공용 presentation widget이 `TimezoneCatalogRepository`의 bundled snapshot을 한 번 load하고 개인·가구 row를 같은 instant에서 계산한다.
- catalog에는 exact identifier lookup을 추가하며 substring이나 device timezone fallback으로 대체하지 않는다.
- draft 언어는 저장 전 앱 전체 locale을 바꾸지 않고 preview subtree의 Material localization에만 적용한다.
- explicit refresh는 새 instant와 새 offset/DST snapshot을 함께 가져오며 background timer는 두지 않는다.
- loading/failure/retry/missing-zone 상태에서도 profile draft와 기존 authoritative content를 유지한다.
- 개인 또는 가구 picker row 선택 시 controller draft만 바꾸고 preview를 즉시 rebuild한다. 기존 save·confirmation 이전에는 repository/RPC mutation을 호출하지 않는다.

## Server, security, and privacy boundary

- migration, RPC, grant, RLS, Edge Function, remote DTO와 profile update payload shape는 변경하지 않는다.
- preview는 display-only이며 timezone persistence와 authorization의 권위자가 아니다. 저장 시 기존 PostgreSQL IANA validation과 expected-version transaction이 그대로 적용된다.
- UTC instant, 검색·선택 이력, preview 결과, locale/timezone 조합을 저장·전송·로그·분석하지 않는다.

## Automated evidence plan

- catalog domain: exact identifier hit/miss와 기존 deterministic search 회귀.
- shared widget: fixed UTC instant의 Seoul/London wall-time 차이, EN→KO draft formatting, system 24-hour preference, failure/retry, missing identifier, explicit refresh.
- profile widget: 개인·가구 picker 선택과 language draft가 preview를 바꾸되 save 전 update call 0, 기존 confirmation/save contract 유지.
- compact 320×568 EN-XA 200%에서 preview와 save까지 scroll 가능하고 refresh target이 48dp 이상인지 확인한다.
- focused suites 후 settings/architecture/localization, analyzer, format, full Flutter, root contract, YAML/matrix, secret와 whitespace gate를 실행한다.

## Manual and deferred evidence

- 실제 Android locale, system 12/24-hour setting, DST 전환, process restart, TalkBack/keyboard와 real-account cross-device 저장은 사용자 지시대로 마지막 통합 Gate에서 검증한다.

## Rollback

- preview widget과 exact lookup helper를 제거해도 기존 picker, profile controller, RPC, stored timezone, recurrence와 notification semantics는 유지된다.
- catalog failure 시 device timezone으로 대체하지 않고 preview만 unavailable로 닫으므로 기능 rollback에 데이터 migration이 필요 없다.
