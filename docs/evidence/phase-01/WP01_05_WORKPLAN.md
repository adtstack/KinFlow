# Phase 01 WP01-05 Work Plan

- 작성일: 2026-07-24
- 기준 commit: `b89538d`
- Work Package: WP01-05 Design/i18n/a11y
- 상태: COMPLETE — automated Gate PASS; Android device/TalkBack follow-up pending

## Requirements

| ID | 구현 범위 |
|---|---|
| WP01-05 | design tokens, compact/medium/expanded scaffold, EN/KO/pseudo locale, semantics/text-scale smoke |
| D-036 | 영어·한국어 동시 기반과 pseudo locale/RTL 구조 검증 |
| FR-PLAT-001 | ARB key coverage와 locale별 생성 output 검증 |
| FR-PLAT-002 | screen-reader semantics, dynamic type, touch target, contrast와 reduced-motion token |
| FR-PLAT-009 | available width 기반 compact/medium/expanded layout |
| NFR-A11Y-01 | WCAG 2.2 AA 지향 foundation smoke; 실제 TalkBack task review는 후속 Gate |
| NFR-I18N-01 | 완전한 번역 문구, pseudo expansion, RTL mirror와 ICU plural foundation |
| T-A11Y-03 | 200% text와 compact/tablet/split-width blocker clipping 0 |
| T-I18N-01 | EN/KO/pseudo exact key coverage와 layout overflow blocker 0 |
| NFR-011/NFR-012 | EN/KO key 100%, 200% text foundation screen clipping 0 |

## UI Contract

- Material 3를 유지하며 brand/semantic color, spacing, radius, elevation, typography scale, 48dp touch target, motion, breakpoint를 app token으로 정의한다.
- 완료·오류 상태는 icon과 text를 함께 사용하고 color만으로 의미를 전달하지 않는다.
- `compact < 600`, `medium 600..<840`, `expanded >= 840` logical pixels로 고정한다.
- compact는 top app header와 single pane, medium은 compact rail과 single pane, expanded는 extended persistent rail과 bounded content를 사용한다.
- screen width가 아니라 `LayoutBuilder`의 available width에 반응해 rotation/split view에도 동일한 contract를 적용한다.
- 모든 shell status body는 scroll fallback을 가져 200% text에서 primary action이 사라지지 않게 한다.

## Localization Contract

- `app_en.arb`가 source이고 `app_ko.arb`가 Store locale 번역이다.
- `en_XA`는 30% 이상 늘어난 LTR pseudo로 materialize한다. 실제 지원하지 않는 Arabic locale은 선언하지 않고 RTL은 강제 `Directionality.rtl` mirror test로 분리한다.
- 세 ARB의 message key 집합을 exact-match로 검사하며 blank translation과 fallback 누락을 허용하지 않는다.
- foundation의 plural message로 ICU generation을 검증한다. 실제 date/time/number product semantics는 해당 feature Work Package에서 locale-aware formatter와 함께 추가한다.
- 사용자 표시 문자열과 semantics label/hint는 ARB를 거친다.

## Data / API / Dependency Impact

- DB migration, seed, RLS, Edge/API contract 변경 없음.
- runtime/dev dependency 추가 없음. Flutter SDK의 Material, gen_l10n, flutter_test만 사용한다.
- network, native permission, 개인정보 처리 변화 없음.

## Planned Tests

1. token 값과 light/dark semantic color extension/contrast contract
2. breakpoint boundary `599/600/839/840`
3. compact/medium/expanded widget layout key와 navigation form
4. EN/KO/en_XA exact message key coverage와 supported locale
5. en_XA 각 message 30% expansion, forced RTL Directionality/mirrored rail
6. localized ICU plural output
7. ready/failure/navigation header semantics와 raw decorative icon exclusion
8. primary action minimum 48x48 logical pixels
9. reduced-motion setting이 motion duration을 zero로 변환
10. 200% text에서 compact/medium/expanded 및 pseudo/KO overflow exception 0
11. format/analyzer warning 0, full Flutter test, l10n/build_runner drift 0
12. dev/prod APK build와 staged-index clean bootstrap/analyze/test/dev build

## Manual Validation

- 연결된 Android device/emulator가 있으면 EN/KO/pseudo/dark/large text와 TalkBack focus order를 확인한다.
- 기기가 없으면 APK metadata와 automated semantics/layout smoke만 PASS로 기록하고 device/TalkBack은 NOT RUN으로 남긴다.

## Non-scope

- 제품용 Today/Chores/Calendar/Family navigation destination과 feature UI
- 사용자 언어 설정 저장/동기화
- 실제 locale date/time/currency UI
- TalkBack/VoiceOver 실제 core journey 승인과 WCAG 전체 audit
- golden baseline의 제품 비주얼 승인
- Web/iOS/desktop platform 지원 선언

## Rollback

- token/theme, responsive scaffold/status layout, pseudo ARB/generated localization과 관련 tests/docs를 함께 되돌리면 `b89538d`의 WP01-04 shell로 복귀한다.
- DB/API/provider/native permission 변화가 없어 data 또는 provider rollback은 없다.
