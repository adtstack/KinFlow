# Phase 03 — 집안일과 Today

## 목표

가족이 집안일을 만들고 담당자·마감·반복을 지정하고, Today에서 확인·완료하며 다른 기기와 안전하게 동기화한다.

## Entry

Household Alpha Gate 통과.

## Work Packages

### WP03-01 Chore domain/schema

- series/revision/occurrence 기본 모델
- title/assignee/due/local intent/state
- household integrity/RLS
- domain state transition

### WP03-02 One-time chore

- create/edit/cancel/detail/list
- server validation/error mapping
- adaptive form/UI

### WP03-03 Assignment and members

- adult/managed assignee
- removed/suspended member behavior
- cross-household FK attack

### WP03-04 Completion

- expected version/idempotency
- complete/uncomplete/optional approval 범위
- actor/acting child audit
- duplicate tap/conflict

### WP03-05 Repeating chore

- supported recurrence subset
- revision/occurrence materialization
- single occurrence and future series edit
- time matrix fixtures

### WP03-06 Today chores

- household date/timezone
- ordering/filter/empty/error/stale
- Realtime invalidation or resume refetch
- performance budget

### WP03-07 Notification event hooks

실제 push 전에 due/assignment domain event와 inbox contract를 기록한다.

### WP03-08 Static chore templates

- PII 없는 앱 내 exact catalog와 localized title
- 추천 반복을 편집 가능한 기존 create draft에만 적용
- template metadata는 DB/API/cache/analytics로 전송하지 않음

### WP03-09 One-time chore lifecycle

- scheduled one-time title/description/assignee/due edit
- series + occurrence expected-version and idempotent conflict recovery
- immutable revision, content-free audit and soft-delete/cancel
- Today adaptive edit/delete UI and offline read-only boundary

### WP03-10 First-household guided chore setup

- 첫 가구 active snapshot 성공 후 protected guided route로 handoff
- PII-free exact catalog에서 서로 다른 template 세 개 선택, title과 daily/weekly 반복 검토·수정
- server-authoritative household date와 current adult assignee로 기존 recurring create 계약 재사용
- 항목별 unique idempotency, 순차 생성, 부분 성공 progress와 실패 항목 same-key retry
- explicit skip/partial-exit confirmation, Today refresh와 EN/KO/EN-XA 200% UI
- process-death resume는 WP03-12에서 local automated로 보강하며 activation analytics, server/household catalog와 실계정·실기기는 후속 Gate

### WP03-11 Adult household activation progress

- active household member 전용 `get_household_activation_progress`에서 distinct adult 2명, series 3개, distinct adult completer 2명과 household-local day-two 경계를 capped aggregate로 파생
- 구성원 제거, chore soft-delete와 완료 reopen 뒤에도 historical milestone을 보존하되 identifier/content/visit analytics는 저장·반환하지 않음
- Today의 기존 핵심 content/action 뒤에 비차단 4단계 카드, 초대/집안일 생성 CTA, projection-only retry와 완료 성공 후 refresh를 제공
- strict five-key DTO, latest-household controller, persistent-cache 제외, cached Today mutation 차단과 EN/KO/EN-XA 200% UI 자동 검증
- 정확한 과거 Today 방문 ledger, remote·실계정·두 기기·실기기는 마지막 Gate

### WP03-12 Process-death-safe guided setup resume

- 제출 직전 frozen exact-three batch만 app-environment별 전용 secure storage에 최대 8 KiB exact schema로 저장하고 입력 중 초안은 저장하지 않음
- 첫 create 전 durable save와 각 성공 뒤 checkpoint-before-next-request를 강제하며 저장 실패 시 server call 0회 또는 다음 call 중단
- 앱 재실행 Today preflight가 exact active household/member record를 발견하면 guided route로 보내고 authoritative Today 확인 뒤 원래 payload·start date·command ID로 남은 항목 자동 재개
- corrupt/version/type/order/scope mismatch는 UI 노출 없이 purge하고 logout/account switch/account deletion composite purge에 참여
- completed 3 clear-only retry와 explicit exit clear-before-navigation, restored frozen EN/KO/EN-XA UI를 자동 검증
- 실제 Keystore/Keychain process kill, 실계정·remote·다중기기·실기기는 마지막 Gate

### WP03-13 One-time chore trash and Undo

- scheduled one-time 삭제 성공 receipt의 post-delete series+occurrence version과 원래 occurrence를 process memory에만 보존해 localized Snackbar 즉시 Undo 제공
- active exact-household member용 exact 18-key 삭제 목록, metadata-only empty row, bounded opaque cursor와 삭제 시각 역순 `/chores/trash` 제공
- deleted/cancelled/once, 원래 active assignee와 dual expected version을 검증해 revision·content·due·assignee를 보존하는 mediated restore RPC
- 기존 caller+key namespace의 cross-operation 충돌, exact replay, immutable content-free restored audit와 chores runtime-policy authority 유지
- persistent trash cache 없이 authoritative reload, strict Flutter DTO/controller, EN/KO/EN-XA compact 200%·48dp UI 자동 검증
- permanent purge·retention·bulk·repeating/completed restore와 실계정·hosted·다중기기·실기기는 마지막 Gate

### WP03-14 Advanced chore recurrence editor

- 반복 집안일 생성과 미래 시리즈 편집에 daily/weekly/monthly 간격 `1..30`과 `never|count 1..1000|until` 종료 조건을 노출
- 생성 weekly/monthly는 시작일에 anchor하고, 동일 frequency 시리즈 편집은 기존 weekday/month-day를 보존하며 frequency 변경은 server-authoritative household 현지 날짜에 다시 anchor
- full strict recurrence rule을 생성 controller fingerprint에 포함해 동일 입력 retry key 재사용과 interval/end 변경 시 새 key를 유지
- template은 interval 1/never로 재설정하고, 시작일 변경은 until을 유효한 household-local 날짜로 보정하며 invalid 입력은 repository/ID/I/O 전에 차단
- EN/KO/EN-XA localized live summary, scrollable compact 200%와 다이얼로그 lifecycle을 자동 검증
- multi-weekday는 WP03-15, guided advanced 설정은 WP03-17에서 확장; ordinal/yearly와 실계정·hosted·다중기기·실기기는 마지막 Gate

### WP03-15 Weekly multiple-weekday selector

- weekly 반복 집안일 생성과 미래 시리즈 편집에서 localized 요일 1~7개를 선택하고 ISO 월요일~일요일 순서로 strict rule에 직렬화
- 생성 start date 요일은 잠긴 anchor로 유지하고 날짜 변경 시 기존 선택에 새 anchor를 추가하며, template 적용은 현재 start weekday 하나로 재설정
- 미래 시리즈 편집은 active rule의 전체 요일을 prefill하고 effective-date 요일 고정 없이 최소 한 요일만 유지하며 changed-to-weekly는 server-authoritative household date 요일로 시작
- frequency 왕복 시 in-progress set을 보존하고 full-rule fingerprint가 같은 retry key 재사용과 weekday 변경 key 회전을 유지
- EN/KO/EN-XA localized helper/live summary, 48dp toggle과 320×568 200% 생성·시리즈 다이얼로그 자동 검증
- monthly 기준일은 WP03-16, guided advanced 설정은 WP03-17에서 확장; multiple month-day·ordinal/yearly와 실계정·hosted·다중기기·실기기는 마지막 Gate

### WP03-16 Monthly day-of-month selector

- monthly 반복 집안일 생성과 미래 시리즈 편집에서 strict `monthDay` 1~31일을 localized dropdown과 live summary로 노출
- 생성은 첫 due date day를 잠긴 anchor로 표시하고 due date 변경 시 표시·직렬화 값을 함께 바꾸며, 미래 시리즈는 active monthDay를 그대로 prefill해 자유롭게 변경
- changed-to-monthly는 server-authoritative household effective local date day로 시작하고 같은 editor의 frequency 왕복 시 in-progress day를 보존
- 선택 날짜가 없는 달은 건너뛰고 말일로 clamp하지 않으며 실제 materialized matching date만 count를 소비한다는 기존 server 정책을 명시
- full-rule fingerprint가 같은 retry key 재사용과 monthDay 변경 key 회전을 유지하고 `0/32` 또는 non-monthly copy는 I/O 전에 차단
- EN/KO/EN-XA localized option/helper/live summary와 320×568 200% 시리즈 dropdown 자동 검증; multiple month dates·last-day·ordinal/yearly와 실계정·hosted·다중기기·실기기는 마지막 Gate

### WP03-17 Guided advanced recurrence setup

- 첫 가구 exact-three guided 설정의 각 항목에서 daily/weekly/monthly, interval `1..30`, `never|count 1..1000|until`을 기존 recurrence editor로 편집
- weekly는 frozen household start weekday를 잠근 채 ISO 순서 복수 요일을 허용하고, monthly는 frozen start day를 기준일로 잠그며 없는 달은 skip-not-clamp
- full strict recurrence rule을 draft fingerprint와 항목별 create request에 보존해 같은 입력은 동일 command ID를 재사용하고 freeze 전 rule 변경은 새 ID를 사용
- submitted batch secure resume을 exact recurrence JSON v2로 올리고 legacy v1은 축소 replay 없이 read/clear 시 삭제하며, unsubmitted 편집 초안은 계속 저장하지 않음
- invalid/noncanonical rule은 command ID·secure write·repository 전에 차단하고 제출 뒤 exact-three 전체 편집을 잠근 채 process recreation에서 동일 payload로 재개
- focused 33개·영향 범위 261개·full Flutter 1,125개와 analyzer/format/codegen/config/secret/docs gate를 통과했으며 remote·실계정·다중기기·실기기는 마지막 Gate로 유지

### WP03-18 Household weekly report

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-09)** — P1 activation and live validation deferred
- active household member가 가구 시간대로 서버가 계산한 최근 완료 ISO 주차부터 최대 12주를 조회
- due/completed-by-week-end/completed-later/open/skipped의 exact aggregate와 최대 20명 active adult 기여를 반환
- removed/deleted/overflow member completion은 identifier와 이름 없이 `other` 합계로 제공
- Today의 비차단 요약 카드와 상세 주차 탐색, source-local retry, EN/KO/EN-XA compact 200% UI
- title, description, occurrence/series ID, auth user ID, email, analytics와 persistent cache는 범위 밖
- contract/evidence: `docs/contracts/household-weekly-report.yaml.md`, `docs/evidence/phase-03/WP03_18_WORKPLAN.md`, `docs/evidence/phase-03/WP03_18_EVIDENCE.md`
- hosted production-size plan, 실제 계정·두 기기·실기기와 product activation 판단은 마지막/P1 Gate

### WP03-19 Searchable internal chore template library

- 상태: **LOCAL AUTOMATED COMPLETE (2026-08-09)** — P1 activation and live validation deferred
- 기존 stable key·상대 순서를 보존한 exact 16-entry·5-category PII-free app-bundled catalog
- one-time/repeating 생성과 first-household exact-three guided setup이 localized title 검색과 category 교집합 browser를 공유
- filter로 가려진 선택·편집 draft를 보존하고 template 선택은 localized title과 daily/weekly 추천 cadence만 기존 create 흐름에 적용
- query/category/selection/key/version의 storage·network·cache·log·analytics 비노출과 DB/API/RLS/SDK/permission 무변경
- EN/KO/EN-XA exact coverage와 KO search·empty/clear·category horizontal scroll·compact 200%·48dp 자동 검증
- contract/evidence: `docs/contracts/chore-templates.yaml.md`, `docs/evidence/phase-03/WP03_19_WORKPLAN.md`, `docs/evidence/phase-03/WP03_19_EVIDENCE.md`
- remote/household catalog·추천·개인화·recent/ranking/analytics와 실제 계정·사용자 연구·실기기는 마지막/P1 Gate

### WP03-20 Chore series edit from selected occurrence

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — P1 activation and live validation deferred
- Owner/Admin은 Upcoming의 active scheduled 반복 회차에서 `이 회차부터 수정`을 선택하며, 서버가 target occurrence의 immutable `recurrence_local_date`를 유일한 경계 authority로 사용
- 선택 경계 이전 회차와 경계 이후 완료 회차의 historical revision·content·completion actor를 보존하고, 이후 미완료 회차는 새 immutable revision의 title·notes·assignee·time·strict recurrence rule로 재구성
- 이후 미완료 한 회차 reschedule/reassign/skip은 새 기본값으로 초기화될 수 있음을 저장 전에 고지하고, same-key replay·different-input collision·series expected-version·target row lock과 content-free aggregate audit를 유지
- Flutter는 Upcoming current-query, scheduled, `canManageSeries`, online cache와 chores runtime policy를 I/O 전에 확인하고 성공·stale·invalid transition 뒤 authoritative current query를 다시 읽음
- 기존 `오늘부터 시리즈 수정`, 한 회차 예외, 전체 취소와 worker는 호환되며 table/column/RLS policy를 추가하지 않고 additive authenticated RPC만 노출
- contract/evidence: `docs/contracts/chore-series-from-occurrence.yaml.md`, `docs/evidence/phase-03/WP03_20_WORKPLAN.md`, `docs/evidence/phase-03/WP03_20_EVIDENCE.md`
- Calendar 동일 범위, hosted 실제 계정·두 기기·timezone boundary·Android 실기기는 마지막/별도 P1 Gate

### WP03-21 Chore series cancellation from selected occurrence

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — P1 activation and live validation deferred
- Owner/Admin은 Upcoming의 미래 active scheduled 반복 회차에서 `이 회차부터 취소`를 선택하며 서버가 target occurrence의 immutable `recurrence_local_date`를 유일한 경계 authority로 사용
- 경계 이전 scheduled 회차와 경계 이후 completed 이력은 보존하고, 경계 이후 skipped/scheduled 등 미완료 회차만 모든 historical revision에서 cancelled로 전이
- 이전 scheduled prefix가 남으면 latest surviving source revision의 content·anchor·assignee·time을 복제한 bounded terminal revision을 활성화하고, prefix가 없을 때만 기존 전체 취소처럼 series를 즉시 soft-delete
- same-key replay·different-input collision·series expected-version·target row lock·content-free aggregate audit와 canonical worker no-regeneration을 유지
- Flutter는 Upcoming future/scheduled/`canManageSeries`/online cache와 chores runtime policy를 I/O 전에 확인하고 성공·stale·invalid transition·target unavailable 뒤 authoritative current query를 다시 읽음
- 기존 전체 취소·시리즈 편집·한 회차 예외와 table/column/RLS grants는 호환되며 cancellation audit/replay check만 optional terminal revision을 허용
- contract/evidence: `docs/contracts/chore-series-cancel-from-occurrence.yaml.md`, `docs/evidence/phase-03/WP03_21_WORKPLAN.md`, `docs/evidence/phase-03/WP03_21_EVIDENCE.md`
- persistent cancellation history, Calendar 동일 범위, hosted 실제 계정·두 기기·timezone boundary·Android 실기기는 마지막/별도 P1 Gate

### WP03-22 Repeating chore cancellation immediate Undo

- 상태: **LOCAL IMPLEMENTED / AUTOMATED PASS (2026-08-10)** — P1 activation and live validation deferred
- 기존 selected-boundary cancellation의 exact signature와 9-key result는 유지하고 첫 실행에서만 private metadata-only pre-state ledger를 캡처
- 원래 cancellation actor가 여전히 active Owner/Admin이고 household·series·terminal shape·exact cancellation-result version이 일치할 때만 additive resume RPC 허용
- cancelled scheduled/skipped row를 원래 상태로 복원하고 pre-cancellation source를 새 immutable resumed revision으로 복제하며, 취소 뒤 completed/edited prefix는 덮어쓰지 않음
- same-key resume replay·different-input conflict·row drift·stale series를 fail closed하고 canonical worker continuation과 content-free immutable `resumed` audit를 유지
- Flutter는 successful selected cancellation의 process-memory receipt만 Snackbar에 노출하고 transient failure는 같은 resume key로 재시도, terminal failure는 receipt 폐기 후 authoritative current-query reload
- runtime chores guard·read-only cache·single-flight·strict DTO/repository/cache invalidation과 EN/KO/EN-XA 48dp Undo를 자동 검증
- contract/evidence: `docs/contracts/chore-series-cancellation-undo.yaml.md`, `docs/evidence/phase-03/WP03_22_WORKPLAN.md`, `docs/evidence/phase-03/WP03_22_EVIDENCE.md`
- process-death history, arbitrary historical resume와 hosted 실제 계정·두 기기·timezone boundary·Android 실기기는 마지막/별도 P1 Gate이며 Calendar immediate parity는 WP04-16에서 구현

## 자동 검증

- domain transition
- RLS CRUD/assignment
- recurrence fixtures
- idempotency/version conflict
- Today query/order/pagination
- widget/a11y/large text

## 수동 검증

- two-device assignment/complete
- managed child completion
- timezone/date boundary
- reinstall/resume
- iPad/Android tablet layout

## Exit Gate

두 가족 구성원이 반복 집안일을 만들고 담당하고 완료한 상태가 양쪽 Today에 일관되게 보인다. 완료 history와 recurrence definition이 분리되어 있다.

## Rollback

recurrence를 feature flag off하고 one-time chore를 유지할 수 있어야 한다. materialization repair script와 audit가 준비되어야 한다.
