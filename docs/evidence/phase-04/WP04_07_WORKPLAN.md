# Phase 04 WP04-07 Same-member Calendar Overlap Hint Workplan

- 상태: `LOCAL AUTOMATED COMPLETE / REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED`
- 범위: Calendar 생성·한 회차 수정·전체 시리즈 수정 editor에서 같은 구성원의 권위 있는 일정 겹침을 미리 보여주되 저장은 차단하지 않는다.
- 제외: 자동 일정 재배치, 참석 가능 시간 추천, 외부 캘린더 busy/free 연동, remote query-plan 측정, 실제 계정·두 기기·실기기 검증

## Requirements

| ID | 이번 slice의 수용 기준 |
|---|---|
| WP04-07 / FR-CAL-008 | 선택한 참석자 중 한 명 이상이 기존 scheduled occurrence에도 포함되고 두 일정 범위가 교차하면 경고 힌트를 표시한다. 힌트의 존재·조회 실패·조회 중 상태는 저장 버튼을 비활성화하지 않는다. |
| FR-CAL-001 / FR-CAL-002 | timed/timed은 server-resolved UTC `[starts_at, ends_at)`으로, all-day/all-day는 `[local_start_date, all_day_end_date_exclusive)`로 비교한다. timed/all-day 교차는 현재 household timezone의 자정 경계로 all-day 날짜 범위를 instant 범위로 해석한다. 끝과 시작이 맞닿기만 하면 겹침이 아니다. |
| FR-CAL-004 | 반복 후보는 원본 local anchor와 recurrence rule을 유지하고, 실제 materialization과 같은 bounded window에서 최대 366개 시작 회차를 전개한다. DST gap은 기존 server resolver와 같은 stable failure로 반환하며 overlap earlier/later 정책을 그대로 적용한다. |
| FR-CAL-005 / FR-CAL-006 | one-time 수정은 해당 series, 반복 한 회차 수정은 해당 occurrence, 전체 시리즈 수정은 해당 series를 후보 비교에서 제외한다. 다른 occurrence와의 겹침은 그대로 남긴다. |
| NFR-SEC-01 / NFR-PRIV-01 | active household member만 RPC를 실행한다. 요청에는 제목·설명·사용자/actor identity를 싣지 않고 schedule, recurrence, participant member ids, optional exclusion ids만 보낸다. 응답은 해결에 필요한 기존 title, 일정 시작 정보와 실제 겹친 구성원만 반환하며 description은 반환하지 않는다. |
| NFR-A11Y-01 / NFR-I18N-01 | 확인 중·겹침 없음·겹침 있음·확인 실패 상태와 계속 저장 가능 안내를 semantic하고 ARB 기반으로 제공한다. pseudo locale에서도 dialog가 overflow하지 않는다. |

## Data and API Impact

- `app_private.calendar_overlap_candidate_dates(...)`: 기존 recurrence subset과 같은 daily/weekly/monthly/count/until 규칙을 arbitrary read-only candidate에 적용하는 private stable helper다. 요청 window는 366일 이내로 제한한다.
- `public.preview_calendar_event_overlaps(...)`: active membership, schedule shape, participant integrity와 optional self-exclusion을 검사하는 stable security-definer RPC다.
- 후보 pair는 같은 구성원의 수와 무관하게 `candidate occurrence × existing occurrence` 한 건으로 센다. 겹친 구성원 배열은 UUID 순으로 정렬한다.
- 결과는 household timezone/local date/generated-at, 확인 window, 후보 회차 수, 전체 겹침 수, truncation과 최대 10개 상세를 반환한다. 상세 정렬은 candidate local date, 기존 household-local 시작, occurrence id 순이다.
- 기존 Calendar create/update/delete/cancel RPC와 테이블 shape는 변경하지 않는 additive migration이다.

## UX and Application Flow

1. editor는 schedule·recurrence·participant가 바뀌면 짧게 debounce한 뒤 새 미리보기를 요청한다. 제목·설명은 판정 입력이 아니므로 요청하지 않는다.
2. 새 입력이 생기면 이전 결과를 즉시 stale 처리하고 늦게 도착한 이전 generation 응답은 무시한다.
3. 결과가 있으면 기존 일정 제목, household-local 시작, 실제 겹친 구성원을 최대 10건 보여주고 전체 건수·bounded 확인 범위를 함께 알린다.
4. 결과가 없으면 확인 완료 상태를, 네트워크/권한/DST 실패면 안전한 확인 실패 상태를 표시한다.
5. 모든 상태에서 사용자는 기존 `Save` action을 실행할 수 있다. 이 기능은 mutation 전제조건이나 optimistic conflict contract가 아니다.

## Verification

- domain request/result invariant와 recurrence window/exclusion tests
- strict Supabase payload mapping, extra/missing/mixed metadata rejection tests
- repository request serialization·result mapping·failure mapping tests
- controller pass-through 및 disposed editor의 late result 무시 tests
- widget 자동 debounce, same-member hint, self-exclusion request, failure에서도 저장 가능, zero result와 pseudo-locale tests
- pgTAP authentication/RLS, participant validation, timed/all-day/cross-kind half-open overlap, different-member negative, self-exclusion, recurring bounded expansion, truncation/order tests
- additive local migration, focused/full DB tests와 product-schema lint, focused/full Flutter tests, analyzer, formatter, l10n/codegen, config/secret/whitespace checks
- destructive clean local reset은 승인 없이 실행하지 않고 기능 개발 이후 마지막 migration-from-zero gate에 유지한다.

## Security and Privacy

- RPC는 `auth.uid()`와 active household membership을 server에서 다시 확인하며 caller-provided user identity나 role을 신뢰하지 않는다.
- 다른 household UUID나 removed member는 `not found or forbidden`/invalid input 경계 밖으로 정보가 새지 않는다.
- 응답에는 description, actor, auth user id, command/idempotency/correlation id, audit material을 포함하지 않는다.
- title과 겹친 member display name은 이미 같은 active household Calendar에서 읽을 수 있는 범위이며, 상세 제한과 deterministic order를 적용한다.
- UI와 로그는 raw provider exception이나 schedule content를 오류 문자열에 포함하지 않는다.

## Rollback

- client overlap domain/data/controller/editor/l10n/tests를 함께 revert하면 기존 Calendar 저장 동작으로 돌아가며 mutation data에는 영향이 없다.
- DB rollback은 authenticated execute grant를 회수한 뒤 public preview RPC와 private candidate helper를 제거한다. 기존 event tables, indexes, command RPC와 occurrence data는 바꾸지 않는다.
- 운영 중 preview 부하나 오류가 확인되면 client 호출을 제거해도 저장 계약은 그대로 유지된다.

## Completion Boundary

- local automated server-authoritative overlap hint가 생성·one-time 수정·반복 한 회차 수정·전체 시리즈 수정에서 동작하고 회귀 gate가 green이면 WP04-07 local slice를 완료한다.
- 결과는 bounded materialized horizon의 힌트이지 전 세계 외부 캘린더까지 포함한 충돌 보장이 아니다.
- remote 규모 query plan, 실제 계정 권한변경 race, 두 기기 동시 편집과 실기기 접근성은 사용자 지시에 따라 기능 개발 이후 마지막 gate에 남긴다.
