# Phase 02 Traceability Refresh Work Plan

- 작업일: 2026-07-30
- 범위: WP02-01 live integration, WP02-02~05 implementation status
- 요구사항: FR-AUTH-003~005, FR-HH-001~008
- 상태: COMPLETE

## Objective

원래 합의한 네 단계와 현재 저장소 구현 상태를 다시 대조하고, living 문서인 README·변경기록·요구사항 추적표의 오래된 상태를 실제 evidence에 맞춘다.

1. WP02-02 household schema/RLS
2. WP02-03 first-household onboarding
3. WP02-04 secure invite
4. Google 로그인과 성인 2인·Android 2기기 live E2E

후속 WP02-05 role/Owner lifecycle은 위 네 번째 항목과 구분한다.

## Change Boundary

- README의 현재 구현 범위와 기준 CI 실행을 최신 상태로 갱신한다.
- 문서 changelog에 WP02-03~05와 Google/App Link 준비 결과를 추가한다.
- requirements traceability의 auth/household 행을 실제 code, migration, evidence와 수동 gate 상태에 맞춘다.
- 네 단계의 자동화 완료와 live 미완료를 한 표에서 확인할 수 있는 status evidence를 추가한다.
- 기존 point-in-time evidence의 당시 결과는 수정하지 않는다.

## Data / API / Security

- DB migration, RLS, Edge Function, Flutter runtime과 외부 provider를 변경하지 않는다.
- 계정 email, OAuth credential, token, Android serial과 household/member identifier를 기록하지 않는다.
- 실제 Google 로그인이나 기기 조작을 수행하지 않는다.

## Validation

- traceability CSV code fence의 헤더와 116개 데이터 행을 보존한다.
- 변경된 경로와 evidence 링크가 저장소에 존재하는지 검사한다.
- repository CI self-test와 secret scan을 실행한다.
- 원격 CI gate가 green인지 확인한다.

## Rollback

문서 전용 커밋을 revert한다. 데이터·API rollback은 없다.

## Completion Boundary

문서 정합성 갱신은 실제 live 결과를 만들지 않는다. Android 2대와 성인 Google 계정 2개로 runbook의 preflight 2개 및 live check 27개를 모두 통과하기 전에는 네 번째 단계와 Phase 02 Exit Gate를 완료로 표시하지 않는다.

## Actual Validation Result

- `git diff --check`: PASS
- requirements traceability: 116 data rows, 18 columns, 변경한 code/migration/evidence path 전부 존재 — PASS
- `npm run ci:test`: 47/47 PASS
- `dart run tool/scan_secrets.dart`: PASS
- `npm run ci:workflow`: 5 jobs, pinned action 17개, `contents: read` contract PASS
- [GitHub Actions 30504563368](https://github.com/adtstack/KinFlow/actions/runs/30504563368): quality 4m05s, backend 3m16s, dependency 1m14s, Android dev 4m44s, Android prod 4m34s, final gate PASS

이 Work Plan의 `COMPLETE`는 traceability refresh에만 적용한다. 합의 순서 4의 실제 live 결과는 계속 `0/27 NOT RUN`이다.
