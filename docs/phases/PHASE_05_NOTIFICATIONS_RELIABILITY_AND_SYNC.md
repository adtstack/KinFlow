# Phase 05 — 알림, 작업 큐, 신뢰성, 제한된 동기화

## 목표

집안일·일정 알림을 서버에서 신뢰성 있게 생성하고, 모바일 앱의 foreground/background/terminated 상태에서 안전하게 전달하며 네트워크 단절과 중복을 처리한다.

## Entry

Chores/Calendar domain event와 occurrence 안정화.

## Work Packages

### WP05-01 Outbox/job worker

- event/outbox schema
- lease/retry/dead letter
- idempotent handler
- monitoring/replay

상태: `LOCAL IMPLEMENTED (2026-08-08)`

- content-free Chore Outbox를 `pending → leased → retry_wait|succeeded|dead_letter`로 처리한다.
- `FOR UPDATE SKIP LOCKED`, opaque lease token, heartbeat, 최대 5회 deterministic backoff+jitter, final lease expiry 격리를 구현했다.
- 최신 occurrence/series/recipient를 재평가해 source event당 candidate 또는 allowlisted suppression을 한 번만 durable하게 확정한다.
- service-role-only mediated API, immutable transition audit, pause/resume, aggregate health와 전용-secret Edge worker를 구현했다.
- clean local reset, DB lint, pgTAP lifecycle/concurrency, pure Edge contract를 자동 검증한다.
- hosted scheduler, remote queue alert/dashboard, endpoint/provider send와 실계정·실기기는 후속 Gate다.

### WP05-02 Notification preferences/inbox

- per-type settings
- quiet hours/timezone
- in-app durable inbox
- read/unread/badge

상태: `LOCAL IMPLEMENTED (2026-08-08)`

- 사용자·household·`chore_due|chore_assignment`별 versioned channel/in-app 설정과 IANA timezone quiet hours를 구현했다.
- 자정 교차와 DST gap/fold를 결정적으로 계산하되 quiet hours는 future delivery timing에만 적용하고 durable inbox 생성은 지연하지 않는다.
- latest state와 현재 preference를 다시 평가해 source event별 `created|disabled|stale|suppressed`를 멱등 확정하고, 새 aggregate version이 이전 active item을 취소한다.
- recipient 전용 content-free inbox, 안정 keyset pagination, 개별/전체 읽음과 server-authoritative badge를 Flutter 화면·repository/controller까지 연결했다.
- clean local reset, pgTAP 기능/격리/DST/동시성, strict DTO·controller·widget·worker contract를 자동 검증한다.
- endpoint/token, 실제 push provider, OS permission/lifecycle/tap deep link, hosted scheduler와 실계정·실기기는 WP05-03/04 및 마지막 검증 Gate에 남긴다.

### WP05-03 Device registration

- installation identity
- FCM token lifecycle
- logout/account switch/removal purge
- invalid token cleanup

상태: `LOCAL IMPLEMENTED (2026-08-08)`

- 환경별 secure installation UUID와 account-bound pending/active binding proof를 분리하고 Android namespace 및 iOS Keychain account를 auth storage와 격리했다.
- authenticated Edge 등록에서 raw provider token을 AES-256-GCM으로 봉인하고 SHA-256 fingerprint로 dedupe하며 registration UUID·expected version으로 response-loss replay, metadata refresh와 token rotation을 구분한다.
- 같은 active fingerprint의 계정 재할당, 256-bit proof 기반 logout/account-switch 해지, member removal 자동 해지와 stale fingerprint가 새 token을 끄지 못하는 provider invalidation을 구현했다.
- Flutter lifecycle은 raw token을 저장하지 않고 pending proof를 network 전에 저장한다. 응답 유실 상태를 현재 callback token으로 exact replay해 동시에 도착한 token rotation을 놓치지 않으며, 원격 해지가 실패하면 proof를 보존하고 auth local purge를 fail-closed 처리한다.
- clean reset, 58개 집중 pgTAP, 13개 Edge 계약, 25개 Flutter 집중 테스트와 전체 회귀로 synthetic token lifecycle을 검증한다.
- Android FCM SDK token 획득, OS permission, provider send/receipt hash, foreground/background/terminated 표시와 tap은 WP05-04에서 로컬 자동화로 연결했다. 실제 Firebase project·실기기와 iOS/APNs는 마지막 Gate/별도 ADR에 남긴다.

### WP05-04 Mobile push

- Firebase/APNs config
- permission pre-prompt
- foreground/local presentation
- background/terminated handler
- deep link tap authz

상태: `LOCAL IMPLEMENTED (2026-08-08)`

- source event를 durable inbox 생성과 독립적으로 재평가해 현재 native-push preference, quiet hours, 최신 occurrence/recipient와 active Android endpoint가 모두 유효할 때만 `(source_event_id, endpoint_id)` delivery를 만든다.
- 최대 5회 lease/finalize와 exact completion replay, stale lease/token fingerprint 방어, FCM permanent invalid-token endpoint 해지, provider receipt 원문 대신 SHA-256 hash, rollback pause/cancel을 구현했다.
- 전용 scheduler secret, versioned AES-GCM decrypt keyring, Firebase service-account OAuth와 FCM HTTP v1 adapter를 연결하되 응답·로그·payload를 식별자/aggregate로 제한했다.
- Android Firebase public options는 optional all-or-none이며, 명시적 알림 센터 action 전에는 OS permission을 요청하지 않는다. denied는 proof purge·설정 이동·durable inbox fallback으로 처리한다.
- Firebase token/rotation을 기존 crash-safe endpoint lifecycle에 연결하고 foreground local presentation, background/terminated/local tap continuation과 authenticated latest-state target 재인가를 구현했다. 실패와 household mismatch는 알림 센터로 fail closed한다.
- clean reset과 48개 집중 pgTAP, 17개 Edge 계약, Flutter parser/coordinator/repository/widget 테스트 및 Android dev debug APK build로 synthetic/fake vertical slice를 검증했다.
- 실제 Firebase project/service account, hosted scheduler, 실계정·실기기 foreground/background/terminated 수신과 OEM matrix는 사용자 지시에 따라 마지막 Gate다. iOS/APNs는 D-021 별도 결정 전까지 제외한다.

### WP05-05 Reliability

- provider outage/backoff
- duplicate/out-of-order
- stale suppression
- queue alert/SLO

상태: `LOCAL IMPLEMENTED (2026-08-08)`

- FCM network I/O 직전 exact lease/token submission marker를 durable하게 남기고, 명시적 429/5xx만 Retry-After·exponential delay·delivery 기반 deterministic jitter로 최대 5회 재시도한다.
- marker 이후 timeout, malformed success, receipt hashing 또는 DB completion 유실은 `FCM_SUBMISSION_AMBIGUOUS` terminal 상태로 격리한다. durable inbox를 fallback으로 유지하며 자동/수동 duplicate replay를 금지한다.
- provider retry는 전역 backoff를 열어 다음 batch claim을 늦춘다. Android notification tag는 delivery ID, TTL은 materialization 뒤 1시간 usefulness window의 남은 초다.
- 만료 retry는 token material을 반환하지 않고 `STALE_DELIVERY_WINDOW`로 취소한다. 최근 `no_endpoint`는 permission/endpoint가 1시간 안에 복구될 때 한 번 재평가한다.
- immutable content-free transition, bounded exhausted-only replay, aggregate provider/queue health와 24시간 95%-within-5m submit SLO 및 low-volume absolute alert를 구현했다.
- clean 29-migration reset, 34-file/1,907-test DB regression과 97-test JavaScript regression을 통과했다. hosted scheduler/dashboard/pager, 실제 Firebase outage/quota, 실계정·실기기 incident drill은 마지막 Gate다.

### WP05-06 Offline/read cache

- stale read cache namespace
- logout/household purge
- one safe chore-completion outbox PoC
- membership/session/version/TTL revalidation

상태: `LOCAL IMPLEMENTED (2026-08-08)`

- Android 전용 encrypted storage의 fixed slot에 active household, chore list와 Today first-page snapshot을 저장한다. exact contract/user/session/household/TTL/size 검증과 기존 strict parser 재검증을 통과한 값만 일시적 provider unavailable 상황에서 표시한다.
- logout, session termination/revocation, account switch, no-active-household와 household change 경계에서 purge 또는 exact replacement하며 purge 실패는 `localPurgeFailed` lock으로 fail closed한다. Web persistent cache는 compose하지 않는다.
- cached-at/reconnect/read-only 상태를 en/ko/en-XA UI에 표시하고 completion/reopen, occurrence/series 변경, create/invite, filter/load-more를 UI와 controller 양쪽에서 차단한다. authoritative refresh가 성공하면 read-only 상태를 해제한다.
- Flutter 전체 회귀 539 pass와 local-connectivity opt-in 1 skip, analyzer issue 0, formatter drift 0 및 config/codegen/secret/whitespace Gate를 통과했다.
- 이 WP 당시 D-018 safety Gate에 필요한 reconnect membership revalidation, response-loss recovery와 실제 기기 forensic이 모두 입증되지 않아 chore-completion outbox를 비활성화했다. 2026-08-09 WP05-10이 앞의 두 항목을 local synthetic Gate로 보강했으며 실제 기기 forensic과 hosted 검증은 계속 마지막 Gate다.

### WP05-07 Calendar event reminders

상태: `LOCAL IMPLEMENTED (2026-08-09)`

- 시간 지정 occurrence는 시작 instant에, 종일 occurrence는 date-only 의미를 유지한 채 authoritative household timezone의 해당 날짜 09:00에 `calendar_event/calendar_occurrence` reminder를 예약한다.
- recurring/exception occurrence는 immutable revision participant snapshot을, one-time legacy occurrence는 current participant fallback을 사용해 참여자별 content-free source event를 만든다.
- insert capture와 worker 선행 sweep을 32일로 제한하고 exact occurrence version·audience로 멱등화한다. 일정 변경·취소·참여자 제거는 최신 상태를 다시 평가해 해당 참여자의 active inbox/push만 stale 또는 cancelled 처리한다.
- 기존 Chore worker RPC 이름과 queue table은 호환성을 위해 유지하면서 resolver, inbox materializer와 Android push claim을 strict Calendar category/subject pair까지 확장했다.
- Flutter inbox/push parser, 알림 센터 category/preference와 EN/KO/EN-XA generic copy를 추가했다. WP05-08에서 authenticated latest-state tap을 exact Calendar occurrence route로 확장했고 실패는 알림 센터로 fail closed한다.
- Calendar 집중 pgTAP 46개, 관련 notification pgTAP 467개, Node 140개와 Flutter 전체 1,004개(+opt-in 1 skip)가 통과했다. hosted scheduler, 실제 Firebase/계정/다중기기/physical-device 검증은 마지막 Gate다.

### WP05-08 Chore occurrence target recovery

상태: `LOCAL IMPLEMENTED (2026-08-09)`

- Chore inbox와 재인가된 Android push가 일반 Today 화면이 아니라 `/chores/occurrence/:occurrenceId`의 정확한 occurrence 상세로 이동한다. Calendar 알림도 기존 exact occurrence route로 이동한다.
- 새 authenticated `get_chore_occurrence_target` RPC는 active household membership과 exact household/occurrence를 재검사하고 scheduled 또는 completed 한 건만 최신 상태로 반환한다.
- skipped, missing, 다른 가구와 삭제된 scheduled series는 같은 unavailable 상태로 처리하고, completed historical occurrence는 삭제된 series에서도 조회할 수 있다.
- 단건 target은 encrypted read cache fallback을 사용하지 않는다. 성공 화면은 기존 bounded activity-history UI를 재사용하고 resume·active-household 변경 시 authoritative refetch한다.
- strict UUID route, Chore/Calendar category별 push destination, inbox read-state 이후 이동, invalid/stale fallback과 EN/KO/EN-XA recovery UX를 로컬 DB·Flutter 자동화로 검증했다.
- 실제 Firebase, 실계정 membership/delete race와 foreground/background/terminated physical-device tap은 사용자 지시에 따라 마지막 Gate다.

### WP05-09 Actionable Chore occurrence target

상태: `LOCAL IMPLEMENTED (2026-08-09)`

- WP05-08 exact 상세에서 server-derived 권한이 있는 scheduled occurrence는 완료, completed occurrence는 다시 열 수 있다. Owner/Admin은 활성 series의 가구 occurrence에, 일반 성인은 현재 자신에게 배정된 occurrence에만 action할 수 있다.
- strict N-1 client가 기존 exact projection을 계속 파싱할 수 있도록 `get_chore_occurrence_target`은 변경하지 않고, 동일 projection에 `can_set_completion` 하나만 더한 authenticated-only `get_chore_occurrence_action_target`을 추가했다.
- actionability는 presentation hint일 뿐이며 기존 `set_chore_occurrence_completion`이 active membership, role/assignee, series state, occurrence state, expected version과 caller-scoped idempotency를 다시 검증한다.
- duplicate tap은 single-flight로 합치고 동일 fingerprint의 응답 유실 재시도는 같은 command ID를 재사용한다. 성공은 local status/version을 적용한 뒤 exact target과 기존 activity history를 다시 읽는다.
- stale/invalid transition은 새 version으로 자동 재전송하지 않고 최신 target으로 조정한다. mutation 성공 뒤 target refresh만 실패하면 성공 상태를 보존하고 별도 재시도를 제공한다.
- direct target/action은 encrypted cache와 offline outbox를 사용하지 않으며 Chores runtime mutation policy를 repository I/O 전에 적용한다. 로컬 pgTAP·Flutter 집중 자동화는 통과했고 실계정 role/assignment·두 기기 race·실기기 TalkBack/notification journey는 마지막 Gate다.

### WP05-10 Bounded Chore completion outbox

상태: `LOCAL IMPLEMENTED (2026-08-09)`

- Android Today/Chores 목록의 cached scheduled 완료 한 건과 online completion의 typed transient failure만 전용 encrypted fixed slot에 저장한다. 완료 취소와 다른 모든 offline write, WP05-09 notification target 상세 action은 계속 차단한다.
- exact auth subject, Supabase session, household, actor member, expected version, original idempotency key와 30분/session-clamped TTL을 검증한다. mismatch·expiry·corruption·가구 전환·logout은 purge한다.
- initial load, explicit refresh, resume와 overdue retry에서 목록 조회 전에 authoritative target을 읽어 현재 membership, `canSetCompletion`, status/version을 다시 확인한다. already-applied `expectedVersion + 1`은 mutation 없이 reconcile하고 exact scheduled target만 같은 key로 재생한다.
- 자동 시도는 target read 전에 durable count를 올려 최대 3회로 제한한다. terminal clear 실패도 최대 count를 저장해 재전송을 막고 authoritative 상태·needs-attention·명시적 discard로 복구한다.
- queued/syncing/paused/reconciled/attention/discarded/expired/unavailable/occupied 상태를 en/ko/en-XA live-region UI로 제공한다. 실제 Android Keystore/process death/airplane mode, hosted membership/session과 두 기기 race는 사용자 지시에 따라 마지막 Gate다.

### WP05-11 Per-user Calendar reminder lead time

상태: `LOCAL IMPLEMENTED (2026-08-10)`

- 사용자·가구별 `calendar_event` preference에 정시·5·10·15·30·60분 전의 고정 선행 시간을 추가했다. Chore category는 항상 0분이다.
- timed start 또는 all-day household-local 09:00 base instant에서 exact recipient lead를 먼저 빼고 기존 quiet-hours/DST와 1시간 usefulness window를 적용한다. source event의 content-free `scheduledAt`은 base instant를 유지한다.
- 기존 preference v1 RPC의 signature·12-key 결과와 기존 lead 보존 쓰기를 유지하고, Flutter는 exact 13-key v2 read/write로 전환했다.
- 변경 시 inbox evaluation이 없고 push evaluation이 없거나 pending인 future Calendar candidate만 원자적으로 재스케줄한다. inbox 또는 terminal push 평가가 끝난 이력은 철회·재발송·시간 변경하지 않는다.
- 동일 occurrence 참여자의 서로 다른 lead, all-day 09:00, quiet-hours 적용 순서, pending push 재계산, evaluated history 동결, N-1 호환과 strict domain/DTO/UI를 로컬 pgTAP·Flutter 자동화로 검증했다.
- hosted scheduler, 실제 Firebase/계정/두 기기/physical-device timing은 사용자 지시에 따라 마지막 Gate다. 복수 reminder는 WP05-13, Snooze는 WP05-12에서 별도 bounded 기능으로 구현했으며 iOS/APNs와 Web Push는 후속 범위다.

### WP05-12 Calendar notification Snooze

상태: `LOCAL IMPLEMENTED (2026-08-10)`

- active caller-owned Calendar inbox item에서 5·10·30분 중 하나를 선택하며 연속 최대 3회, occurrence base start 후 1시간 이내로 제한한다. 서버가 현재 occurrence·participant와 남은 window로 허용 가능한 최대 선택지를 계산한다.
- optimistic item version, caller-generated UUID, advisory lock과 private immutable metadata-only ledger로 response-loss replay를 중복 없이 처리하고 payload가 다른 key 재사용은 거부한다.
- 원본 inbox item의 read/cancel과 authoritative badge, 기존 pending push cancellation, 새 content-free `calendar.occurrence_reminder_snoozed` source 생성과 receipt 저장을 한 트랜잭션으로 처리한다. terminal 평가·provider 이력은 보존한다.
- 새 source는 기존 latest-state resolver, quiet hours, durable inbox, active Android endpoint와 reliable push delivery worker를 그대로 사용한다. 명시적 Snooze 시각은 이후 lead preference 변경으로 이동하지 않는다.
- 기존 v1 inbox RPC는 유지하고 Flutter는 exact 16-key v2 조회와 9-key command receipt를 strict parse한다. 고정 선택 sheet, 즉시 목록/badge 갱신, same-command retry와 EN/KO/EN-XA·200% text-scale UI를 연결했다.
- 실제 Firebase, hosted scheduler, 실계정·두 기기·physical-device timing/permission/timezone/DST는 사용자 지시에 따라 마지막 Gate다. arbitrary duration, persistent history, iOS/APNs와 Web Push는 후속 범위이며 복수 reminder는 WP05-13에서 구현했다.

### WP05-13 Per-user Calendar multiple reminders

상태: `LOCAL IMPLEMENTED (2026-08-10)`

- 기존 fixed 기본 알림 1개에 distinct 추가 시간 최대 2개를 선택한다. 추가 배열은 Calendar-only, 오름차순, `0/5/10/15/30/60`분 어휘이며 총 fan-out은 3개로 제한한다.
- v1 exact 12-key는 기본·추가를 모두 보존하고 v2 exact 13-key는 기본만 편집하면서 추가를 보존한다. Flutter가 사용하는 additive v3는 exact 14-key로 전체 집합을 strict read/write한다.
- 기존 `calendar.occurrence_start_changed` exact 5-key content-free payload를 유지하고 private source lead identity만 추가한다. 기본과 각 추가 source는 기존 worker, recipient quiet hours, durable inbox, Snooze와 reliable Android push를 독립적으로 사용한다.
- occurrence/horizon capture는 수신자의 전체 current set을 생성한다. 설정 변경은 아직 미래인 새 source만 추가하고 미평가 resolution/pending push만 재계산하며, 제거된 source는 latest-state에서 stale 처리하고 평가 완료 이력은 동결한다.
- strict DB 50-case, Flutter domain/DTO/repository/controller/settings UI 30-case, 전체 DB 64 files/3,197 tests, 전체 Flutter 1,360 tests와 repository Gate 및 Android dev APK를 통과했다.
- hosted scheduler, 실제 Firebase, 실계정, 두 기기, physical-device timing/permission/timezone/DST는 사용자 지시에 따라 마지막 Gate다. arbitrary time/count, per-occurrence override, iOS/APNs와 Web Push는 후속 범위다.

### WP05-14 Generic notification email fallback

상태: `LOCAL IMPLEMENTED (2026-08-10)`

- 기존 category별 `email` preference를 기본 OFF로 노출하고 in-app inbox·Android push와 독립적으로 저장한다. 빠른 토글과 상세 편집기는 다른 채널, quiet hours, timezone과 Calendar reminder 집합을 그대로 보존한다.
- candidate source를 latest occurrence/recipient/preference와 확인된 Auth email까지 재검사해 address-free private delivery로 materialize한다. email 주소는 service-only claim에서 전송 직전에만 반환하며 queue·transition·log·evidence에는 저장하지 않는다.
- 각 delivery는 기존 recipient IANA quiet hours와 source schedule 뒤 1시간 usefulness window를 사용한다. 최대 5회이며 명시적 `429/500/502/503/504`만 `1m/5m/30m/2h` 범위로 재시도한다.
- provider 제출 직전 exact lease marker를 먼저 영속화한다. marker 이후 network 결과가 불명확하면 `EMAIL_SUBMISSION_AMBIGUOUS`로 terminal 격리하고 자동 재발송하지 않으며 optional provider message ID는 SHA-256만 저장한다.
- Edge worker는 dedicated Bearer의 body/query 없는 POST만 받고 aggregate count만 반환한다. SendGrid Web API v3 fixed endpoint에 SDK 없이 한 명의 confirmed address와 fixed EN/KO generic text만 보내며 family content, ID, deep link, HTML, attachment와 custom args를 금지한다.
- focused DB 68-case, Node sender/worker 13-case, Flutter notification widget 10-case, full DB 65 files/3,265 tests, Node 154 tests, Flutter 1,361 tests와 opt-in 1 skip, repository quality Gate 및 Android dev APK를 통과했다. hosted SendGrid sender/domain/reputation/quota, 실제 mailbox/account/spam, 두 기기와 실기기는 사용자 지시에 따라 마지막 Gate다.

### WP05-15 Chore Realtime invalidation

상태: `LOCAL IMPLEMENTED (2026-08-10)`

- Chore occurrence insert/update, series update, household member/household update를 household별 content-free generation으로 집계하고, active member만 읽을 수 있는 `chore_sync_watermarks` 한 행을 Supabase Realtime에 게시한다.
- Today primary/overdue와 Chores Hub는 exact household 채널만 구독한다. 연결 직후·새 generation·재연결·resume마다 현재 query first page를 authoritative하게 다시 읽으며 duplicate/역순/in-flight 신호는 무시하거나 한 번의 후속 조회로 합친다.
- 연결 단절이나 transport failure는 마지막 성공 Chore를 stale로 유지하고 명시적 재연결을 제공한다. 권한 상실은 retained content를 즉시 폐기하고, 가구 전환/dispose는 이전 채널을 결정적으로 제거한다.
- published payload는 household ID, monotonic generation, UTC changed-at만 포함한다. title, 설명, 구성원, series/occurrence, actor, command/correlation 식별자는 저장·전송하지 않는다.
- clean 66-migration reset, focused pgTAP 29개, strict adapter/session/controller/provider/UI 자동화와 analyzer 0건을 통과했다. 전체 DB/Flutter 회귀와 production Web build 결과는 WP 증적에 고정한다.
- hosted Supabase propagation, 실계정, 두 기기 race와 foreground/background/network physical-device UX는 사용자 지시에 따라 마지막 Gate다.

### WP05-16 Notification Center Realtime invalidation

상태: `LOCAL AUTOMATED PASS (2026-08-10)`

- inbox item insert/update, category preference insert/update, household member/household authorization update를 auth user별 content-free generation으로 집계하고, 본인만 읽을 수 있는 `notification_sync_watermarks` 한 행을 Supabase Realtime에 게시한다.
- Today/Chores badge와 Notification Center는 화면 수명 동안 exact auth user 채널 하나만 구독한다. 연결 직후·새 generation·재연결·resume마다 현재 active household의 preferences, inbox first page와 unread count를 authoritative하게 다시 읽는다.
- duplicate/역순 generation은 무시하고 action/load 중 변화는 한 번의 후속 조회로 합친다. pagination 중 invalidation은 cursor merge 대신 first page로 교체한다.
- 연결 단절이나 transport failure는 마지막 성공 inbox·badge·preference를 stale로 유지하고 EN/KO/EN-XA 재연결 action을 제공한다. 인증·가구 권한 상실은 retained content를 즉시 폐기하며 user/household 전환과 dispose는 이전 채널을 제거한다.
- published payload는 auth user ID, monotonic generation, UTC changed-at만 포함한다. household/member/item/source/category/read/content/command/correlation 정보는 저장·전송하지 않는다.
- clean 67-migration reset, focused pgTAP 42개, focused Flutter 30개, 전체 DB 3,349개와 Flutter 1,424개, analyzer 0건 및 production Web build를 통과했다. exact 결과와 digest는 WP 증적에 고정한다.
- background 전역 구독·app-shell badge는 WP05-17에서 local automated scope로 연결했다. hosted Supabase propagation, 실계정, 두 기기 race, suspended-process background, foreground/background/network physical-device UX와 외부 provider 전달은 사용자 지시에 따라 마지막 Gate다.

### WP05-17 App-shell Notification Sync and Global Badge

상태: `LOCAL AUTOMATED PASS (2026-08-10)`

- 인증 user와 active household가 있는 앱 셸 수명 동안 root `NotificationCenterLifecycleHost` 하나가 snapshot과 self-user Realtime channel을 유지한다. Today·Chores·Calendar·Family·Settings route 이동은 같은 provider와 channel을 재사용한다.
- resume은 기존 channel을 교체하고 active household의 authoritative first page를 다시 읽는다. 화면별 resume 소유권은 제거했고 Notification Center와 Today/Chores initial read는 idempotent `ensureLoaded` fallback만 유지한다.
- user/household/no-household 전환은 기존 snapshot·unread badge를 먼저 폐기하고 old channel을 취소한다. controller context epoch가 전환 중 끝난 load·mutation 응답을 무시해 같은 household 재진입에서도 이전 content가 다시 나타나지 않는다.
- 공용 app-shell action은 다섯 primary destination에서 같은 server-authoritative unread count를 표시하고 durable Notification Center를 연다. 0은 시각 label을 숨기고, 양수는 `99+`로 제한하며 EN/KO/EN-XA semantics와 200% text scale을 지원한다.
- DB, RPC, publication, provider payload, native permission, route, analytics와 persistent cache는 변경하지 않고 WP05-16 snapshot·watermark 계약을 재사용한다.
- controller/widget/lifecycle 집중 테스트와 전체 Flutter·품질 Gate·production Web build 결과는 `WP05_17_EVIDENCE.md`에 고정한다. hosted Supabase, 실계정, 두 기기, suspended-process background, physical-device lifecycle/network와 외부 provider delivery는 마지막 Gate다.

## 자동 검증

- queue lease/crash/retry/dead letter
- notification dedupe/quiet hours
- payload privacy
- token rotation/purge
- deep link parser
- outbox auth binding

## 수동 검증

- Android actual device permission states
- foreground/background/terminated push
- notification tap after resource delete/membership removal
- provider/network outage
- account switch and cache forensic check

## Exit Gate

inbox는 durable하고 push는 중복 폭주 없이 주요 앱 상태에서 동작한다. 서버 worker가 중요한 알림 시간의 권위다. offline 범위가 명시적으로 승인된다.

## Rollback

push worker kill switch, provider pause, pending job quarantine, local completion outbox feature flag가 존재한다.
