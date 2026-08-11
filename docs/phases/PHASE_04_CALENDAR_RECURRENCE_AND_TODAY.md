# Phase 04 — 공유 일정, 반복, 시간대, Today 통합

## 목표

가족이 종일/시간 지정 일정을 공유하고 반복·예외·참석자를 관리하며, 시간대와 DST에서도 정확한 occurrence를 Today에 통합한다.

## Entry

Chores Value Gate 통과, recurrence time library ADR 승인.

## Work Packages

### WP04-01 Time primitives

- Instant/LocalDate/LocalTime/IANA timezone
- all-day exclusive date range
- DST gap/overlap policy
- serialization contract

### WP04-02 One-time event

- create/edit/delete
- timed/all-day
- household participants
- validation/RLS

### WP04-03 Calendar views

- PRD가 정한 day/month/list scope
- compact/tablet adaptive
- locale first day/date formatting
- accessible navigation

### WP04-04 Recurring event

- series/revision/occurrence/exception
- single edit/cancel
- future/whole series edit
- completed/past preservation policy
- 2026-08-07 local automated status: create/materialization, single-occurrence
  exception, whole-series edit/end와 exception-aware rolling repair까지 완료했다.
  Remote scheduler, real-account/two-device와 real-device timezone gate는
  기능 개발 이후 마지막 검증 단계로 유지한다.

### WP04-05 Today integration

- chores/events combined sections
- same household local date
- deterministic ordering
- performance/cache invalidation
- 2026-08-07 local automated status: Calendar와 Chore source를 exact
  household/timezone/server-local-date/member-filter context에서 합성하고 bounded
  paging, Everyone/Me, quick-complete 유지, source별 stale/retry와 양방향 partial
  failure, 200% pseudo locale까지 완료했다. MASTER의 세분화된 다섯 구간 순서,
  persistent offline, remote 성능과 real-account/device gate는 남아 있다.

### WP04-06 Conflict/concurrency

- expected version
- concurrent edits
- deleted/stale deep link
- Realtime reconnect
- 2026-08-08 local automated status: expected-version 실패 뒤 locator와
  authoritative refetch 복구, UUID occurrence deep link, 삭제·취소·권한변경
  fail-closed 화면, household-scoped content-free watermark Realtime,
  duplicate/out-of-order/in-flight drain, disconnect content retention과
  reconnect/resume full refetch를 Calendar와 Today Calendar source에 완료했다.
  Clean 24-migration reset, full 1,565 pgTAP과 Flutter 464 tests(+ opt-in 1
  skip)가 통과했다. 실제 계정·두 기기 Realtime, remote query plan과 실기기
  gate는 남아 있다.

### WP04-07 Same-member overlap hint

- timed/all-day/mixed half-open overlap preview
- same active household participant intersection
- one-time, single-occurrence, and whole-series self-exclusion
- bounded recurrence expansion and deterministic truncation
- 2026-08-08 local automated status: Calendar 생성·one-time 수정·반복 한 회차
  수정·전체 시리즈 수정 editor에 350ms debounce된 권위 있는 same-member
  overlap 힌트를 추가했다. 요청은 제목·설명을 전송하지 않고 최대 366 후보와
  10개 상세만 반환하며 checking/none/conflict/unavailable 모든 상태에서 저장은
  가능하다. additive migration 40개 상태에서 전체 2,422 pgTAP과 Flutter 829
  tests(+ opt-in 1 skip)가 통과했다. clean reset, hosted 규모 query plan, 실제
  계정·두 기기와 실기기 접근성 검증은 기능 개발 이후 마지막 gate에 남긴다.

### WP04-08 Detailed Today feed

- overdue chores → now/next events → due-today scheduled chores → remaining
  events → due-today completed chores의 결정적 순서
- Calendar server `generatedAt` 기준 all-day·진행 중·가장 가까운 다음 일정 분류
- 독립 overdue source, source-local partial failure/retry와 optimistic quick-complete
- due-today completed 최초 접힘과 기존 completed history tab 보존
- 2026-08-08 local automated status: exact household/timezone/server-local-date/member
  filter가 일치하는 두 Chore source와 Calendar source를 다섯 구간으로 합성했다.
  occurrence 중복 없이 canonical order를 보존하며 완료 구간은 기본 접힘이다.
  focused 23 tests, 기존 Chore widget 23 tests와 전체 Flutter 834 tests(+ opt-in
  1 skip), fatal analyzer 및 repository contracts가 통과했다. DB/API 변경은 없다.
  production-size latency, remote·실계정·두 기기·실기기 검증은 마지막 gate다.

### WP04-09 Persistent Today Calendar cache

- 기존 Android environment-scoped encrypted read-cache에 identifier-free fixed
  `today_calendar_v1` slot 추가
- household/session/member-filter, server-local date, server `generatedAt`, canonical
  projection과 최대 500 occurrence를 exact domain revalidation 후 복원
- transient initial failure에서만 process-restart snapshot을 stale/read-only로 표시하고
  cached-at, 이유와 authoritative retry 제공
- Calendar one-time/recurring/series/occurrence 8개 mutation 성공 시 slot invalidation,
  authorization loss·logout·household transition 시 전체 또는 mismatched cache purge
- 2026-08-09 local automated status: timed/all-day/recurring/exception/empty snapshot,
  corrupt·중복·순서·household·filter mismatch fail-closed, cold restore와 recovery,
  empty-state 포함 EN-XA 200% UI를 완료했다. Flutter 848 tests(+ opt-in 1 skip),
  fatal analyzer, exact formatter/codegen/config/secret 검증이 통과했다. DB/API·runtime
  dependency·permission은 변경하지 않았다. 실제 Android Keystore process death,
  airplane mode, remote membership removal와 실계정·실기기는 마지막 gate다.

### WP04-10 Advanced recurrence editor

- Calendar 생성과 전체 시리즈 편집에 interval `1..30`과
  `never|count 1..1000|until` 종료 조건을 제공한다.
- 동일 frequency는 서버에서 읽은 multi-weekday/month-day anchor를 보존하고,
  changed frequency는 active revision event local start date에 다시 anchor한다.
- 편집 중 full rule을 overlap preview와 draft fingerprint에 전달하고 invalid 범위는
  preview·command ID·repository 이전에 차단한다.
- 2026-08-09 local automated status: bounded domain factory/copy, create·whole-series
  prefill/update, until clamp, full-rule overlap preview, retry key reuse/rotation,
  EN/KO/EN-XA live summary와 compact 200% 자동화를 완료했다. DB/API 변경은 없다.
  hosted·실계정·두 기기·DST/datepicker 실기기 검증은 마지막 gate다.

### WP04-11 Weekly multiple-weekday selector

- Calendar 생성과 전체 시리즈 편집의 weekly rule에서 요일 1~7개를 선택한다.
- event local start date 요일은 항상 선택하고 해제할 수 없으며 다른 요일은 자유롭게
  추가·해제한다. wire rule은 locale과 무관한 ISO 월요일~일요일 순서다.
- start date 변경은 기존 선택을 유지하면서 새 anchor를 추가하고, frequency 왕복은
  editor 안의 선택을 보존한다.
- 2026-08-09 local automated status: bounded canonical domain copy, create·whole-series
  prefill/update, exact overlap preview, weekday fingerprint key rotation, localized card/live
  summary와 EN-XA compact 200% chip wrap을 완료했다. DB/API 변경은 없다. hosted·실계정·
  두 기기·실기기 검증은 마지막 gate다.

### WP04-12 Monthly start-date anchor synchronization

- monthly rule의 `monthDay`를 event local start date와 항상 동기화한다.
- missing date는 마지막 날로 보정하지 않고 건너뛰며 interval/end를 보존한다.
- 2026-08-09 local automated status: 생성·전체 시리즈 편집·frequency 왕복·overlap
  preview·idempotency와 localized summary를 완료했다. DB/API 변경은 없다. hosted·
  실계정·두 기기·실기기 검증은 마지막 gate다.

### WP04-13 External calendar file import

- Android document picker에서 사용자가 명시적으로 선택한 UTF-8 `.ics` 파일만 읽는다.
- RFC 5545의 bounded one-time/all-day와 기존 daily/weekly/monthly recurrence subset을
  strict parse하고, 일정별 미리보기·선택과 공통 household participant 선택 뒤 기존
  Calendar create command로 순차 복사한다.
- provider 계정·broad calendar/storage permission·자동 sync·외부 UID persistence는
  추가하지 않는다. 재가져오기 중복 가능성과 지원하지 않는 일정 수를 명시한다.
- 2026-08-09 local automated status: strict parser·Android gateway·preview/selection·
  sequential same-key retry·runtime guard·EN/KO/EN-XA compact 200% UI와 dev debug APK
  compile을 완료했다. 실 document provider·실계정·hosted·두 기기·실기기는 마지막
  gate이며 WP04/G4 전체는 완료가 아니다.

### WP04-14 Calendar series edit from selected occurrence

- active household member는 scheduled recurring non-exception 회차에서 `이 회차부터 수정`을 선택한다.
- 서버는 target occurrence의 immutable recurrence slot을 경계로 사용하고 client date는 authority로 받지 않는다.
- 경계 이전 occurrence와 경계 이후 기존 한 회차 예외는 그대로 보존하며, 이후 non-exception source slot만 새 immutable revision으로 reuse/rebuild/cancel한다.
- 기존 오늘-boundary 전체 수정 signature·request hash·result와 한 회차 수정/취소·전체 종료는 호환된다.
- 2026-08-10 local automated status: selected target/revision/future guard, full-rule retry identity, boundary-aware editor/overlap preview, strict additive RPC와 35-case pgTAP, full DB/Flutter 회귀 및 Android dev compile을 완료했다. hosted·실계정·두 기기·timezone boundary·실기기는 마지막 통합 Gate다.

### WP04-15 Calendar series cancellation from selected occurrence

- active household member는 scheduled recurring non-exception 회차에서 `이 회차부터 취소`를 선택한다.
- 서버는 target occurrence의 immutable recurrence slot을 경계로 사용하고 client date는 authority로 받지 않는다.
- 경계 이전 occurrence와 explicit exception은 표시 날짜와 무관하게 보존하고, 경계 이후 모든 occurrence는 moved exception을 포함해 취소한다.
- actionable non-exception prefix가 남으면 source snapshot·participant·anchor를 복제한 `until = boundary - 1` terminal revision으로 worker 재생성을 막고, 없을 때만 시리즈를 경계에서 종료한다.
- 기존 오늘-boundary 전체 종료 signature·hash·9-key result, 전체/선택 시리즈 수정과 한 회차 수정/취소는 호환된다.
- 2026-08-10 local automated status: strict additive RPC와 48-case pgTAP, selected target/revision/future guard, retry-stable Flutter domain/data/controller, Today cache invalidation 및 EN/KO/EN-XA compact 200% confirmation을 완료했다. full DB 59-file/2,951-test·Flutter 1,336-test 회귀와 Android dev APK contract도 통과했으며 hosted·실계정·두 기기·timezone boundary·DST·실기기는 마지막 통합 Gate다.

### WP04-16 Calendar selected-boundary cancellation immediate Undo

- active household member가 selected-boundary cancellation에 성공하면 현재 controller lifetime의 persistent Snackbar에서 즉시 Undo할 수 있다.
- 기존 cancellation 5-input/11-key 계약은 유지하고 private metadata-only pre/post ledger가 취소로 바뀐 occurrence와 bounded terminal-prefix repoint를 exact actor+command로 기록한다.
- original actor가 현재 active member이고 cancellation-result series version·terminal/ended shape·cancelled suffix post-state가 그대로일 때 source snapshot·participants를 새 immutable resumed revision으로 복제한다.
- moved explicit exception의 이전 status/semantics와 scheduled/completed/skipped suffix를 복원하고 unchanged prefix repoint만 새 revision에 연결하며 later-edited prefix는 보존한다.
- transient 실패와 server success 뒤 reload 실패는 동일 resume key와 receipt를 유지하고 authoritative reload 성공 뒤에만 정리한다. terminal conflict와 scope/competing mutation은 receipt를 폐기한다.
- 2026-08-10 local automated status: clean migration reset, 58-case Undo pgTAP, legacy 48-case cancellation compatibility, full DB 62-file/3,100-test, Flutter 집중 130-test·전체 1,351-test 회귀, analyzer·product-schema lint와 Android dev APK contract를 통과했다. 320×568 EN-XA 200%에서도 Undo가 scroll로 도달 가능하며 hosted·실계정·두 기기·timezone boundary·DST·process-death·실기기는 마지막 통합 Gate다.

## 자동 검증

- TIME_RECURRENCE_TEST_MATRIX 전부
- participant household integrity/RLS
- all-day round trip
- materialization idempotency
- Today exact-context five-section order and no-duplicate partition
- serialization locale independence

## 수동 검증

- DST 대표 timezone device tests
- device timezone travel change
- Android date picker
- Android phone/tablet adaptive layout
- two-device concurrent edit

## Exit Gate

one-time/recurring/all-day event가 시간대 정책에 따라 안정적으로 표시되고 single occurrence와 series 수정 의미가 분리된다.

## Stop/Rollback

DST fixture 또는 과거 occurrence 보존 실패 시 반복 일정 출시 금지. one-time event만 feature flag로 유지 가능해야 한다.
