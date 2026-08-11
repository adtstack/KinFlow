# WP04-04B Work Plan — Single Recurring Occurrence Edit and Cancel

- 상태: LOCAL AUTOMATED COMPLETE / LIVE GATES DEFERRED
- 범위: FR-CAL-005의 "이번 회차만 수정"과 "이번 회차만 취소", immutable occurrence exception history, mixed v2 agenda·day·month projection
- 선행 조건: WP04-04A recurring create/materialization과 one-time Calendar CRUD/v2 mixed read local automated baseline
- 후속 범위: future/whole-series edit·cancel과 rolling repair worker는 WP04-04C, Today composition은 WP04-05, Realtime multi-client conflict는 WP04-06이다.

## 요구사항과 수용 기준

| ID | 수용 기준 |
|---|---|
| FR-CAL-005 | 반복 일정의 한 회차를 수정하면 target occurrence만 새 immutable exception revision을 사용한다. source series/active revision, immutable recurrence slot/key와 sibling occurrence는 바뀌지 않는다. |
| FR-CAL-005 | 반복 일정의 한 회차를 취소하면 target occurrence만 cancelled 상태가 되고 v2 page/month에서 제외된다. source series와 sibling occurrence는 유지된다. |
| FR-CAL-005 | 한 회차에는 household 범위 unique exception row 하나만 존재하며 반복 수정은 exception version과 pointer를 전진시키고 이전 revision history를 보존한다. |
| D-019/D-020 | series/revision/occurrence/exception을 분리하고 MVP scope는 "이번 회차"와 "전체 시리즈"만 사용한다. 04B는 "이번 회차"만 구현하며 "이후 모든 회차"를 추가하지 않는다. |
| D-048/NFR-REL-01 | update/cancel은 expected occurrence version과 UUID idempotency를 사용한다. 동일 key+payload replay는 같은 결과를 반환하고 key 재사용·stale version은 stable code로 거부한다. |
| FR-CAL-007 | moved edited occurrence는 새 local date/time overlap과 ordering으로 정확히 한 번 보이며 원래 날짜에서는 사라진다. cancelled occurrence는 page와 month counts 모두에서 빠진다. |
| NFR-SEC-01/NFR-PRIV-01 | JWT actor, active household membership과 same-household active participant를 서버가 다시 검증한다. command/audit storage에는 title, description, display name 또는 participant list를 복제하지 않는다. |

## DB/API 영향

1. `event_occurrence_exceptions`를 additive하게 추가한다. baseline-compatible `override_payload`는 빈 object로 제한하고 실제 override는 immutable `event_series_revisions`와 `event_revision_participants`로 정규화한다.
2. exception은 household/series/occurrence composite identity와 optional exception revision, cancelled flag, actor timestamps, monotonic version을 보존한다. target occurrence의 immutable `recurrence_local_start_date`와 `occurrence_key`는 변경할 수 없다.
3. `update_recurring_calendar_occurrence(...)` authenticated RPC는 full event draft를 검증하고 새 revision/participant snapshot을 생성한 뒤 target occurrence와 exception pointer만 원자적으로 전진시킨다.
4. `cancel_recurring_calendar_occurrence(...)` authenticated RPC는 target occurrence와 exception row만 cancelled로 전진시킨다. cancelled occurrence update와 one-time occurrence 호출은 transition error로 거부한다.
5. 두 RPC는 content-free private command replay row와 Calendar audit metadata를 남기며 API role은 private state나 public table mutation 권한을 갖지 않는다.
6. 기존 v2 snapshot/page/month function signatures는 유지하고 occurrence exception marker와 target revision을 projection에 반영한다. v1 one-time contracts는 변경하지 않는다.

## Flutter 영향

1. platform-free occurrence update/cancel requests와 strict result snapshot을 추가하고 transition failure를 provider-neutral domain failure로 매핑한다.
2. repository/controller는 occurrence version을 사용한 optimistic command, same-key retry와 authoritative page/month refresh를 수행한다.
3. recurring card에 localized "이번 회차 수정"·"이번 회차 취소" action을 열고 one-time update/delete와 명령 경로를 분리한다.
4. 수정된 회차는 localized exception label을 표시한다. 반복 series의 여러 occurrence가 한 화면에 있을 때 card/action key는 occurrence identity로 고유해야 한다.
5. 새 사용자 문자열은 en/ko/en-XA ARB와 generated localization을 통해서만 제공한다.

## 자동 검증

- pgTAP: schema/FK/index/trigger/RLS/grants, unauthenticated/anonymous/outsider/cross-household denial, malformed/stale/not-recurring/cancelled transition, participant validation, DST gap atomicity, update/cancel idempotency conflict/replay, repeated edit history, source/sibling/slot immutability, v2 moved/cancelled page/month projection, content-free command/audit rows.
- Flutter: request/result invariants, strict DTO/error mapping, repository RPC mapping, controller refresh/same-key retry/stale handling/time preview, recurring occurrence edit/cancel UI, exception label, duplicate-series occurrence key uniqueness, Korean/pseudo-locale/200% editor regression.
- clean database reset, focused/full pgTAP, strict DB lint, Flutter focused/full test, analyzer/formatter, lockfile replay, l10n/codegen drift, config/secret and whitespace checks.

## 보안·개인정보

- public exception family는 force RLS/read-only authenticated household access이며 direct insert/update/delete grant가 없다.
- security-definer command는 empty search path, JWT-derived actor와 server-side membership/participant validation을 사용한다.
- command replay와 audit에는 content/participant identity list를 저장하지 않는다. `override_payload`는 `{}`만 허용하고 content-bearing generic JSON override를 사용하지 않는다.
- 새 native permission, OS Calendar 접근, analytics payload, persistent event cache 또는 external network dependency를 추가하지 않는다.

## Rollback

- production 적용 전에는 04B migration, Flutter occurrence command/UI/l10n, tests/contracts/evidence를 함께 revert하고 04A의 21-migration/1,342-pgTAP 및 407-Flutter baseline을 clean reset으로 확인한다.
- production 적용 후에는 applied migration을 수정·삭제하지 않는다. corrective forward migration으로 04B RPC execute를 revoke하고 client occurrence actions를 숨기되 기존 exception/history row를 파괴하지 않는다.

## Stop 조건

- target edit/cancel이 source series/active revision, sibling occurrence, recurrence slot/key를 변경하거나 materializer replay가 exception을 덮어쓰면 출시하지 않는다.
- replay duplicate revision, stale overwrite, cross-household participant, RLS bypass, content-bearing private command/audit storage 또는 v1/v2 one-time regression이 있으면 04C로 진입하지 않는다.

## 완료 판단

04B가 green이어도 whole-series change, rolling repair worker, Today composition, conflict/Reconnecting Realtime, remote·real-account·two-device·device-travel 검증이 남으므로 FR-CAL/Phase 04/전체 제품 목표를 완료로 표시하지 않는다.

2026-08-07 local automated gate는 clean 22-migration reset, focused 65/65 및 full 1,407 pgTAP, focused 48/48 및 full 419 Flutter tests(+ opt-in 1 skip), DB lint/analyzer/formatter/lockfile/l10n/codegen/config/secret/whitespace checks 전부 통과했다. 상세 결과와 deferred 범위는 `WP04_04B_EVIDENCE.md`에 기록한다.
