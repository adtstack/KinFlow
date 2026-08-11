# Phase 03 WP03-14 Advanced Chore Recurrence Editor Evidence

## Status

- 결과: **LOCAL AUTOMATED SLICE PASS (2026-08-09)**
- 범위: `FR-CHORE-005`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-017`
- 계약: `docs/contracts/chore-advanced-recurrence.yaml.md`
- 작업계획: `docs/evidence/phase-03/WP03_14_WORKPLAN.md`
- 이 결과는 WP03/G3/출시 완료가 아니다. 실제 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate다.

## Delivered slice

| Layer | Result |
|---|---|
| Domain | `ChoreRecurrenceRule.tryAnchored`가 daily/weekly/monthly interval `1..30`과 `never|count 1..1000|until`을 생성 시작일에 대해 검증한다. `tryWithIntervalAndEnd`는 동일 frequency의 기존 weekdays/month-day anchor를 보존한다. |
| Creation | 생성 controller/provider가 frequency 대신 완성된 strict rule을 받아 draft에서 시작일과 다시 검증한다. full rule은 fingerprint에 포함돼 동일 입력 retry는 같은 command ID를, interval/end 변경은 새 ID를 사용한다. |
| Series edit | Today 미래 시리즈 편집이 현재 interval/end를 prefill한다. frequency가 같으면 저장된 anchor를 보존하고, 바뀌면 기존 server-authoritative household effective date로 새 anchor를 만든 뒤 기존 versioned update/reload 흐름을 사용한다. |
| UX | 재사용 editor가 interval, 종료 방식, count 또는 household-local until picker와 live summary를 제공한다. 생성일 변경은 until을 유효 범위로 올리고 template은 interval 1/never로 재설정한다. |
| Validation | interval/count의 keyboard·form·domain bounds가 invalid input을 command ID/repository/I/O 전에 차단한다. until picker는 시작일 이전을 선택할 수 없고 domain이 같은 경계를 다시 검증한다. |
| Accessibility/i18n | EN/KO/EN-XA generated ARB, locale-aware plural/date summary, scrollable 320×568 200% layout, 48dp 이상 controls와 live region을 추가했다. |
| Lifecycle | 시리즈 dialog가 닫힘 전환을 완료한 뒤 외부 text controller를 dispose해 reverse-animation 중 disposed-controller 접근을 막는다. |

## Authority and reliability evidence

1. server schema, migration, RPC, RLS, Edge와 recurrence materializer는 변경하지 않았다. 기존 database rule validator와 mediated create/update RPC가 최종 authority다.
2. client factory와 form validation은 advisory fail-fast이며 unsupported rule을 server 권한으로 승격하지 않는다.
3. unchanged-frequency edit은 multi-weekday 또는 month-day를 그대로 복사하고 interval/end만 바꾼다. changed-frequency edit만 household effective date에 anchor한다.
4. 동일 normalized full rule retry는 command ID를 재사용하고, interval 또는 end가 달라지면 fingerprint와 command ID가 함께 바뀐다.
5. guided exact-three setup은 의도적으로 daily/weekly, interval 1, never end의 빠른 activation 경계를 유지한다.
6. chores runtime feature guard, expected-version conflict mapping, authoritative Today reload와 raw provider error 비노출 경계는 기존 흐름을 그대로 사용한다.

## Automated verification

| Command / suite | Result |
|---|---|
| focused exact Flutter domain/controller/widget | PASS — 75 tests |
| one-time chore widget suite | PASS — 35 tests including count/until mapping, template reset, invalid bounds, both series-anchor paths and compact 200% |
| full exact Flutter `flutter test --reporter compact` | PASS — 978 tests, optional 1 skipped |
| exact Flutter 3.44.7 analyzer with fatal infos/warnings | PASS — issue 0 |
| exact Dart 3.12.2 format check | PASS — 573 files / changed 0 |
| generated code drift | PASS — 8 generated files / drift 0 |
| localization contract | PASS — EN/KO/EN-XA exact key coverage and generated ICU plurals in full suite |
| public config and secret scan | PASS — examples allowlisted / high-confidence finding 0 |
| repository Node self-test | PASS — 136 tests |
| contract and matrix parse | PASS — advanced recurrence YAML and 13 fenced CSV documents with declared row/column counts exact |
| `git diff --check` | PASS — whitespace error 0 |

## Traceability updates

- `docs/contracts/chore-advanced-recurrence.yaml.md`
- `docs/contracts/README.md`
- `docs/matrices/REQUIREMENTS_TRACEABILITY.csv.md`
- `docs/matrices/TEST_MATRIX.csv.md` — `T-CHORE-RECURRENCE-EDITOR`
- `docs/matrices/README.md`
- `docs/phases/PHASE_03_CHORES_AND_TODAY.md`
- `docs/MASTER_SPEC.md`
- `docs/CHANGELOG.md`

## Deferred gates and honest boundary

1. 실제 성인 두 계정과 두 기기에서 create/edit propagation, stale version과 reconnect UX는 아직 실행하지 않았다.
2. hosted Supabase와 production-size materialization/DST gap-fold 결과는 마지막 remote Gate다. 이번 client-only slice는 DB reset이나 hosted deployment를 요구하지 않는다.
3. TalkBack/VoiceOver, physical keyboard, Android/iOS date picker와 200% font의 실제 기기 경험은 남아 있다.
4. weekly multiple weekdays 편집, ordinal weekday, multiple month dates, yearly/business-day/exception-calendar와 guided advanced recurrence는 구현하지 않았다.
5. Store build, signed artifact와 실계정 테스트는 사용자 지시에 따라 가장 마지막에 유지한다.

## Rollback

- advanced editor와 full-rule presentation parameter를 제거하고 기존 interval 1/never anchored creation으로 돌아갈 수 있다.
- server schema/RPC/RLS 변경이 없으므로 server rollback은 없다. 기존 advanced rules가 이미 저장돼 있다면 단순 UI rollback 전에 read/display 호환성을 유지한다.
