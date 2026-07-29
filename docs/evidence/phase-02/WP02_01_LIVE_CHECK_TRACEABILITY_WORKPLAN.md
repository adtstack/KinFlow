# Phase 02 WP02-01 Live Check Traceability Work Plan

- 작성일: 2026-07-29
- 기준 commit: `914f19e`
- Work Package: WP02-01 — exact 27-check completion audit
- 상태: IMPLEMENTED — EXACT 27/27 MAPPED / LIVE 0/27

## Requirements

1. completion validator의 exact 27개 key를 빠짐없이 현재 automated evidence와 매핑한다.
2. synthetic/unit/DB/App Link probe가 증명하는 범위를 실제 two-device 관찰로 과대 해석하지 않는다.
3. 각 check의 live 상태와 실제 관찰 방법을 명시한다.
4. same-household/distinct-member 확인은 UUID/email을 evidence에 저장하지 않고 실행 가능해야 한다.

## Scope

- check별 automated coverage를 `PASS` 또는 `PARTIAL`로 구분
- 모든 live 상태를 실제 관찰 전 `NOT RUN`으로 유지
- membership 확인을 두 기기의 Today route와 operator-private Supabase Table Editor 대조로 구체화
- raw account/device/household/member/invite 식별자를 screenshot, SQL history, shared log와 tracked evidence에 남기지 않는 절차 고정

## Explicit Non-scope

- 실제 Android target, Google account, Supabase session 또는 invite 실행
- completion JSON의 `not_run`을 `pass`로 변경
- app UI에 UUID/pseudonymous fingerprint 추가
- DB/API/provider/config 변경

## Validation

- validator와 template의 exact key set 대조
- traceability table 27-row 수동/검색 검증
- runbook privacy/stop condition 일관성 확인
- repository contract와 secret scan

## Completion Boundary

- traceability는 남은 증거 위치를 명확히 할 뿐 live 결과를 만들지 않는다.
- 모든 check는 actual 두 기기 관찰과 completion validator PASS 전까지 Phase 02 Exit Gate에서 pending이다.

## Current Result

- validator의 authoritative key 27개를 순서와 이름까지 exact match로 대조했다.
- device-independent automated contract는 `PASS` 17개, SDK/OS/two-account 관찰이 남은 항목은 `PARTIAL` 10개로 분류했다.
- actual two-device 결과는 과대 표기 없이 27개 모두 `NOT RUN`으로 유지했다.
- same-household/distinct-member는 Supabase Table Editor에서만 대조하고 이메일·UUID를 clipboard, query history, screenshot, log와 tracked evidence에 남기지 않는 실행 절차로 고정했다.
- repository self-test 39개, workflow contract, `git diff --check`와 secret scan이 통과했다.
