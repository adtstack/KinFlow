# Phase 10 WP10-03A Web Core Keyboard and Focus Workplan

## Status

- **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)**
- Vertical slice: Web focus visibility policy → exact-five keyboard navigation → shared modal focus containment → opener focus return → architecture regression
- Requirements: FR-PLAT-010, NFR-A11Y-01, NFR-WEB-002
- Decisions: D-028, D-036, D-070
- Contract: `docs/contracts/web-keyboard-focus.yaml.md`
- Test: T-WEB-03 with existing T-WEB-07 trace alias

## Product boundary

1. Web에서 Tab/Shift+Tab으로 핵심 control을 이동하고 Enter로 exact-five primary destination과 modal action을 실행할 수 있어야 한다.
2. Web focus highlight는 pointer 입력 이후에도 숨지 않도록 traditional mode로 유지하고 Material theme의 공용 focus color를 사용한다.
3. 앱이 소유한 dialog와 modal bottom sheet는 열릴 때 focus를 요청하고 내부 traversal을 closed loop로 제한한다.
4. modal이 닫히면 opener가 여전히 attach되어 있고 focusable인 경우 첫 후속 frame에 focus를 복원한다. opener가 제거·비활성화되면 안전하게 no-op한다.
5. 전체 Web route는 browser chrome이나 embedding host로 이동할 수 있도록 parent-scope traversal을 유지한다. 필수 task는 커스텀 shortcut에 의존하지 않는다.
6. 실제 계정, hosted origin, 실제 browser·screen reader·물리 키보드 검증은 마지막 통합 Gate로 남긴다.

## DB, API and dependency impact

- DB migration, RLS, RPC, Edge contract와 server payload 변경은 없다.
- runtime 또는 dev dependency를 추가하지 않는다.
- focus state를 저장하거나 network·analytics로 전송하지 않는다.
- 기존 route, domain, repository와 Riverpod ownership은 변경하지 않는다.

## Implementation plan

1. bootstrap에서 Web만 `FocusHighlightStrategy.alwaysTraditional`을 적용하고 native의 automatic policy를 보존한다.
2. light/dark theme에 color-scheme-derived visible focus color를 정의한다.
3. `showAppDialog`와 `showAppModalBottomSheet` 공용 wrapper에 request-focus, closed-loop와 guarded opener restore를 구현한다.
4. billing, calendar, chores, household, notifications, settings와 공용 timezone picker의 raw modal call 30개를 wrapper로 전환한다.
5. raw `showDialog`/`showModalBottomSheet` 재도입을 차단하는 architecture test를 추가한다.
6. 합성 인증 상태에서 expanded exact-five route를 Tab과 Enter만으로 순회하고, 독립 harness에서 Tab/Shift+Tab/Enter/Escape와 focus return을 검증한다.

## Automated verification

- modal dialog/sheet closed-loop, Enter/Escape와 opener focus restoration widget tests
- Web traditional focus highlight와 theme focus color policy test
- synthetic authenticated expanded exact-five keyboard-only route test
- raw Flutter modal call architecture guard
- adaptive layout, 200% text, semantics, RTL와 existing feature widget regressions
- analyzer warning 0, exact Dart formatting, Flutter full suite and Web release build

## Manual and deferred verification

- latest Chrome/Edge/Firefox/Safari의 실제 Tab/Shift+Tab/Enter/Escape 동작
- browser-native 200% zoom/reflow와 light/dark focus appearance contrast
- NVDA/JAWS/VoiceOver 대표 조합의 spoken order와 modal announcement
- hosted HTTPS authenticated journey와 실제 계정 전환
- 실제 물리 키보드·assistive technology·실기기

## Security and privacy

- focus node와 route result는 process-memory UI state이며 저장하지 않는다.
- opener 복원은 이미 소유한 focus node에만 적용하고 global navigator key나 arbitrary selector를 사용하지 않는다.
- family content, identity, route input, key event와 focus history를 log 또는 analytics로 보내지 않는다.
- modal wrapper는 authorization, recent authentication, RLS와 destructive confirmation 의미를 변경하지 않는다.

## Rollback

- bootstrap의 Web focus policy와 theme focus color를 제거하면 native behavior는 그대로 유지된다.
- callsite를 Flutter 기본 modal 함수로 되돌린 뒤 wrapper와 architecture guard를 제거할 수 있다.
- DB/API/persisted state 변경이 없어 data rollback이나 migration은 필요 없다.

## Exit condition

- local implementation exit는 focused/full automation, analyzer, format와 Web build가 모두 통과할 때 충족한다.
- FR-PLAT-010, T-WEB-03, PDOD-052와 Web Beta Gate는 실제 browser/screen-reader/zoom/real-account 검증 전까지 `PARTIAL`이다.
