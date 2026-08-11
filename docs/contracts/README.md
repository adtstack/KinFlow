# KinFlow 계약 문서 — Markdown 전용판

이 디렉터리는 구현 계약의 원문을 Markdown 코드 블록으로 보존합니다. 충돌 시 `DECISIONS.md` → `SPEC_BASELINE.md` → 이 계약 문서 → 상세 문서 순으로 해석합니다.

실제 구현에서는 `MD_ONLY_FORMAT_GUIDE.md`에 따라 코드 블록을 원본 파일로 추출하고 parser/validator를 실행합니다.

범위 예외: `managed_child`, `member_guardians`, `acting_contexts`, parental gate, child 전용 event/RLS/API는 P1 참조 계약이다. D-013의 별도 승인 전에는 Store MVP migration/API/client로 추출하거나 활성화하지 않는다.

WP01-12 Web Companion 베이스라인은 Flutter dev/prod release build, path URL, email-first 인증, exact Web runtime identity/policy, no-PWA/no-persistent-cache와 exact-five provider fallback을 `web-companion-baseline.yaml.md`에 정의한다. hosted HTTPS/CSP/SPA rewrite·OAuth callback·실계정·browser matrix와 Web Push/구매는 독립 Web Gate까지 완료 범위가 아니다.

WP10-03A Web 키보드·focus 계약은 standard Tab/Shift+Tab/Enter/Escape, Web traditional focus highlight, exact-four keyboard navigation과 Today 소유 Chores 보조 흐름, 앱 소유 dialog/modal sheet의 closed-loop와 opener focus return을 `web-keyboard-focus.yaml.md`에 정의한다. 실제 browser·200% zoom·screen reader·hosted 인증·실계정/실기기 증적은 마지막 Web Gate까지 완료 범위가 아니다.

WP10-03B Web route recovery 계약은 fixed continuation marker, same-runtime session-expiry exact 복귀, refreshed sign-in coarse 복귀, logout·identity·household 전환 격리와 unknown/invalid/forbidden safe recovery를 `web-route-recovery.yaml.md`에 정의한다. hosted SPA rewrite·실browser history/BFCache·실계정 전환 증적은 마지막 Web Gate까지 완료 범위가 아니다.

WP06-01 billing 계약은 `database-schema.sql.md`, `rls-contract.sql.md`, `domain-events.yaml.md`에 함께 정의한다. WP06-04 signed webhook과 authoritative provider refresh는 `billing-reconciliation.yaml.md`, WP06-05 명시적 household 선택·provisional binding·충돌·audited remediation은 `billing-assignment.yaml.md`, WP06-06 lifecycle·policy-neutral activation·member/recurring-series 집행은 `billing-feature-enforcement.yaml.md`에 정의한다. verified provider event 적용과 plan/runtime/support/enforcement activation은 service-only이고, active household member에게는 provider customer·event·transaction·receipt·다른 household/owner 식별자가 제거된 aggregate projection만 노출한다. D-027 확정 전 ingestion과 feature enforcement는 disabled이고 limits는 unfinalized/fail-closed다.

WP07-01 앱 내 계정 삭제의 exact Edge shape, 최근 OAuth 증명, 24시간 취소 창, last-Owner/구독 제약, leased worker, shared-data 보존, identity tombstone과 Auth soft-delete 순서는 `account-deletion.yaml.md`에 정의한다. 공개 웹 요청, household deletion/export와 실계정·Store·hosted scheduler 검증은 이 계약의 완료 범위가 아니다.

WP07-02A 개인 데이터 내보내기의 본인 범위, exact Edge shape, JSON/TXT leased generation, private Storage, hash-only 일회성 다운로드, revoke·expiry purge와 Flutter URL 처리 경계는 `data-export.yaml.md`에 정의한다. 다른 구성원 identity와 전체 shared household archive는 의도적으로 제외하며 Owner 전용 household export, 실계정·hosted Storage/scheduler·browser/device 증적은 후속 Gate다.

WP07-02B Owner 전용 shared-household export와 가구 삭제의 exact preflight/status, JSON/TXT 20 MiB 경계, hash-only one-time grant, 24시간 cooling-off, retention hold, access revocation·redaction·billing unlink와 Flutter 상태/확인 흐름은 `household-privacy.yaml.md`에 정의한다. Store 구독 자동 취소, 구성원 계정 삭제, hosted scheduler/Storage와 실계정·browser·다중기기·실기기 증적은 완료 범위가 아니다.

WP07-03A 짧은 초대 코드의 혼동 문자 제외 alphabet, hash-only 저장, 최대 24시간 TTL, 공개 preview·인증 accept의 분리된 10회/10분 lockout, generic invalid 오류, raw-once 발급과 process-memory Flutter continuation은 `invite-short-code.yaml.md`에 정의한다. 256-bit HTTPS 링크가 primary capability이며 hosted WAF/proxy·실계정·실기기 증적은 마지막 Gate다.

WP07-06A 성인 본인 profile display/avatar preset, EN/KO locale, 개인 IANA timezone과 Owner/Admin 가구 기본 timezone의 atomic expected-version 저장·membership 표기 동기화·반복 semantics 영향 고지는 `profile-preferences.yaml.md`에 정의한다. 업로드 avatar와 hosted/실계정/실기기 증적은 마지막 Gate다.

WP07-07A 앱 내 terms/privacy/support 허브의 enum-only fixed destination, HTTPS 신뢰 경계, document-local publication/version authority, informational-only consent와 export/account-deletion 바로가기는 `legal-support-hub.yaml.md`에 정의한다. 최종 법률 문구·정책 버전·동의 필요성, 공개 사이트 배포와 실browser/실기기 증적은 후속 Gate다.

WP07-08 로컬 진단 보고서의 exact 9-key allowlist, runtime/configured app-build 일치, coarse platform, per-report UUID v4, PII-free structured correlation과 write-only explicit clipboard 경계는 `diagnostic-report.yaml.md`에 정의한다. 계정·가구·content·token·network·device fingerprint는 금지하며 signed artifact·실clipboard·screen-reader·remote correlation 증적은 마지막 Gate다.

WP03-08에서 시작하고 WP03-19가 확장한 앱 내 집안일 빠른 시작은 PII 없는 exact 16-entry/5-category catalog, ARB localized title 검색·category filter, 추천 daily/weekly 반복과 기존 create request로만 이어지는 editable draft 경계를 `chore-templates.yaml.md`에 정의한다. query/category/selection과 template ID/version은 저장소·서버·analytics로 전송하지 않으며 server/household-specific catalog와 실계정·실기기 증적은 후속 Gate다.

WP03-09 단건 집안일 수명주기는 active adult의 scheduled one-time update/delete, series와 occurrence 이중 expected-version, 새 immutable revision, soft-delete/cancel, content-free audit와 idempotent replay를 `one-time-chore-lifecycle.yaml.md`에 정의한다. completed 직접 변경, trash/undo/bulk, managed-child 권한과 실계정·remote·실기기 증적은 후속 Gate다.

WP03-10 첫 가구 집안일 빠른 설정은 exact 3개 unique local template, editable title과 daily/weekly 반복, server-authoritative household date, current adult assignee, 기존 recurring-create 요청의 항목별 unique idempotency와 부분 성공 same-key retry를 `guided-chore-setup.yaml.md`에 정의한다. 세 요청은 비원자적이며 activation analytics, server catalog와 실계정·remote·실기기 증적은 후속 Gate다.

WP03-11 성인 가구 활성화 진행도는 distinct historical adult account 2명, chore series 3개, distinct adult completer 2명과 가구 생성 로컬 날짜 이후 현재 Today 평가를 capped aggregate로 파생하는 authenticated RPC와 비차단 Today 카드를 `household-activation-progress.yaml.md`에 정의한다. visit/analytics row와 persistent client cache는 만들지 않으며 정확한 과거 day-two 방문, 실계정·remote·다중기기·실기기 증적은 마지막 Gate다.

WP03-12 제출된 guided exact-three batch의 process-death 복구는 전용 secure storage, exact household/member scope, 최초 mutation 전 durable save, 성공별 checkpoint-before-next-request, 동일 payload/command ID 자동 replay, Today preflight와 clear-before-exit을 `guided-chore-setup-resume.yaml.md`에 정의한다. 입력 중 초안·DB/API·telemetry는 추가하지 않으며 실제 Keystore/Keychain process kill, 실계정·remote·다중기기·실기기 증적은 마지막 Gate다.

WP03-13 scheduled one-time chore 휴지통과 Undo는 process-memory deletion receipt, exact 18-key bounded trash projection, deleted/cancelled/once·원래 active assignee·dual expected-version 복원, 기존 caller+key idempotency namespace와 content-free audit 경계를 `one-time-chore-trash.yaml.md`에 정의한다. persistent trash cache, 영구 삭제·retention·bulk·repeating/completed restore는 제외하며 실계정·hosted·다중기기·실기기 증적은 마지막 Gate다.

WP03-14 고급 집안일 반복 편집은 기존 server-supported daily/weekly/monthly strict rule의 interval `1..30`, `never|count 1..1000|until` 종료 조건, 생성 anchor와 동일-frequency anchor 보존, changed-frequency household-date re-anchor 및 full-rule idempotency fingerprint를 `chore-advanced-recurrence.yaml.md`에 정의한다. multi-weekday는 WP03-15, guided advanced 설정은 WP03-17에서 확장하며 server schema/RPC/RLS는 변경하지 않는다. ordinal/yearly와 실계정·hosted·다중기기·실기기 증적은 마지막 Gate다.

WP03-15 weekly 집안일 복수 요일 선택은 unique 1~7개 weekday, 생성 start-date anchor 잠금, 미래 시리즈 최소 1개 규칙, ISO 순서 직렬화, date/template/frequency 전환 보존과 full-rule idempotency 경계를 `chore-weekly-weekdays.yaml.md`에 정의한다. monthly 기준일은 WP03-16, guided advanced 설정은 WP03-17에서 확장하며 server schema/RPC/RLS는 변경하지 않는다. multiple month-day·ordinal/yearly와 실계정·hosted·다중기기·실기기 증적은 마지막 Gate다.

WP03-16 monthly 집안일 월 기준일 선택은 strict `monthDay` 1~31, 생성 due-date anchor 잠금, 미래 시리즈 active 값 prefill·변경, changed-to-monthly household-date 초기화, frequency 왕복 보존, missing-date skip-not-clamp와 full-rule idempotency 경계를 `chore-monthly-month-day.yaml.md`에 정의한다. guided advanced 설정은 WP03-17에서 확장하며 server schema/RPC/RLS는 변경하지 않는다. multiple month dates·last-day·ordinal/yearly와 실계정·hosted·다중기기·실기기 증적은 마지막 Gate다.

WP03-17 첫 가구 exact-three guided 설정의 고급 반복은 각 항목에서 daily/weekly/monthly, interval `1..30`, `never|count 1..1000|until`, frozen-start weekday를 포함하는 ISO 복수 요일과 frozen month-day를 편집하고 full strict rule을 draft fingerprint·retry payload·secure submitted batch에 보존하는 경계를 `guided-chore-advanced-recurrence.yaml.md`에 정의한다. secure resume은 exact recurrence JSON의 v2로 올리고 legacy v1을 재생 없이 정리한다. DB/API/RLS는 변경하지 않으며 remote·실계정·다중기기·실기기 증적은 마지막 Gate다.

WP03-18 가구 주간 리포트는 active adult가 서버 시간과 현재 가구 IANA timezone으로 파생된 최근 완료 ISO 주차 12개를 조회하고, due·completed-by-week-end·completed-later·open·skipped 및 최대 20명 active contributor만 받는 경계를 `household-weekly-report.yaml.md`에 정의한다. removed/deleted/overflow contributor는 count-only `other`로 합치고 content identity·analytics·persistent cache를 금지하며 hosted 규모·실계정·다중기기·timezone boundary·실기기 증적은 마지막 Gate다.

WP03-20 반복 집안일 선택 회차 이후 수정은 active scheduled occurrence의 immutable recurrence slot을 server-owned boundary로 사용하고 이전·완료 이력을 보존하면서 이후 미완료 회차를 새 immutable revision으로 재구성하는 경계를 `chore-series-from-occurrence.yaml.md`에 정의한다. 기존 오늘-boundary RPC와 한 회차 예외는 유지하고 Calendar·실계정·hosted·다중기기·실기기 증적은 후속 Gate다.

WP03-21 반복 집안일 선택 회차 이후 취소는 같은 server-owned recurrence slot부터 이후 미완료 회차를 취소하고, 이전 scheduled prefix가 남으면 source content·anchor를 보존한 bounded terminal revision으로 worker 재생성을 막으며 prefix가 없을 때만 즉시 soft-delete하는 경계를 `chore-series-cancel-from-occurrence.yaml.md`에 정의한다. 기존 전체 취소·편집과 table/column/RLS grant는 유지하며 Calendar parity는 WP04-15가 확장하고 live 증적은 후속 Gate다.

WP03-22 반복 집안일 선택 경계 취소 즉시 Undo는 기존 cancellation RPC를 N-1 호환 wrapper로 유지하면서 private metadata-only pre-state ledger, original actor/current Owner/Admin/exact version 검증, 새 immutable resumed revision과 status 복원, same-key resume replay 및 process-memory Snackbar receipt 경계를 `chore-series-cancellation-undo.yaml.md`에 정의한다. Calendar immediate parity는 WP04-16이 확장하며 process-death history·arbitrary historical resume와 live 증적은 후속 Gate다.

WP04-07 같은 구성원 일정 겹침 미리보기의 content-free request, half-open timed/all-day/mixed 비교, bounded recurrence, self-exclusion, 최대 10건 상세와 저장 비차단 UI 계약은 `calendar-overlap-preview.yaml.md`에 정의한다. hosted 규모 query plan, 실제 계정·두 기기·실기기 증적은 마지막 Gate다.

WP04-08 Today 상세 feed의 exact source context, overdue → now/next → due-today scheduled → remaining → due-today completed 순서, Calendar server `generatedAt` authority, occurrence 무중복 partition, 완료 기본 접힘과 source-local partial failure는 `today-composition.yaml.md` v3에 정의한다. production-size latency와 remote·실계정·두 기기·실기기 증적은 마지막 Gate다.

WP04-09 Android Today Calendar의 authenticated session/household/member-filter scoped encrypted fixed-slot snapshot, transient-only fallback, strict domain revalidation, stale/read-only UI와 Calendar mutation invalidation은 `today-calendar-cache.yaml.md`에 정의한다. Web/iOS persistence와 실제 Keystore·계정·기기 forensic은 후속 Gate다.

WP04-10 고급 Calendar 반복 편집은 기존 server-supported daily/weekly/monthly strict rule의 interval `1..30`, `never|count 1..1000|until` 종료 조건, 생성 anchor와 동일-frequency 다중 weekday/month-day 보존, changed-frequency active-start re-anchor, full-rule overlap preview·idempotency fingerprint를 `calendar-advanced-recurrence.yaml.md`에 정의한다. server schema/RPC/RLS는 변경하지 않으며 multi-weekday 선택·ordinal/yearly와 실계정·hosted·다중기기·실기기 증적은 마지막 Gate다. 선택 회차 이후 편집은 WP04-14가 확장한다.

WP04-11 weekly Calendar 복수 요일 선택은 unique 1~7개 weekday, event local start-date anchor 잠금, ISO 순서 직렬화, start-date/frequency 전환 보존, create·whole-series full-rule preview와 idempotency 경계를 `calendar-weekly-weekdays.yaml.md`에 정의한다. server schema/RPC/RLS는 변경하지 않으며 multiple month-day·ordinal/yearly와 실계정·hosted·다중기기·실기기 증적은 마지막 Gate다. 선택 회차 이후 편집은 WP04-14가 같은 full-rule 경계를 재사용한다.

WP04-12 monthly Calendar 기준일 동기화는 strict `monthDay` 1~31, event local start-date anchor 잠금, 생성·동일-frequency 전체 시리즈 날짜 변경·frequency 왕복 재고정, missing-date skip-not-clamp와 full-rule preview/idempotency 경계를 `calendar-monthly-anchor.yaml.md`에 정의한다. server schema/RPC/RLS는 변경하지 않으며 독립·복수 month date, last-day·ordinal/yearly와 실계정·hosted·다중기기·실기기 증적은 마지막 Gate다. 선택 회차 이후 편집은 WP04-14가 같은 start-anchor 경계를 재사용한다.

WP04-13 외부 Calendar 파일 가져오기는 Android SAF로 명시적으로 선택한 UTF-8 `.ics` 파일, 256 KiB·50 VEVENT bound, RFC 5545 line unfolding/TEXT/date/date-time과 KinFlow 호환 recurrence subset, 일정별 skip·선택 미리보기·공통 participant·순차 idempotent create 경계를 `calendar-file-import.yaml.md`에 정의한다. provider account·broad permission·원본/UID persistence·자동 sync는 금지하며 hosted·실계정·다중기기·실기기 증적은 마지막 Gate다.

WP04-14 반복 Calendar 선택 회차 이후 수정은 active scheduled non-exception occurrence의 immutable recurrence slot을 server-owned boundary로 사용하고 이전 occurrence와 모든 explicit one-occurrence exception을 보존하면서 이후 source slot만 새 immutable revision으로 재구성하는 경계를 `calendar-series-from-occurrence.yaml.md`에 정의한다. 기존 오늘-boundary signature·hash·result와 한 회차 예외는 유지하며 selected cancellation은 WP04-15가 확장하고 live 증적은 후속 Gate다.

WP04-15 반복 Calendar 선택 회차 이후 취소는 같은 immutable recurrence slot부터 이후 모든 occurrence를 moved explicit exception까지 취소하고, 이전 actionable non-exception prefix가 남으면 source snapshot·participant·anchor를 보존한 `until = boundary - 1` terminal revision으로 worker 재생성을 막으며 없을 때만 시리즈를 경계에서 종료하는 계약을 `calendar-series-cancel-from-occurrence.yaml.md`에 정의한다. 기존 오늘-boundary 전체 종료의 signature·hash·9-key result와 전체/선택 수정·한 회차 예외를 유지하며 immediate Undo는 WP04-16이 확장한다.

WP04-16 반복 Calendar 선택 경계 취소 즉시 Undo는 기존 selected-cancellation 5-input/11-output RPC를 호환 wrapper로 유지하면서 private metadata-only pre-state ledger, original actor/current active-member/exact version·post-state 검증, moved exception을 포함한 status 복원, 새 immutable resumed revision, same-key response-loss replay와 process-memory scrollable Snackbar receipt 경계를 `calendar-series-cancellation-undo.yaml.md`에 정의한다. process-death history·arbitrary historical resume와 hosted·실계정·다중기기·timezone/DST·실기기 증적은 마지막 Gate다.

WP05-07 Calendar 일정 시작 알림은 timed start instant, all-day household-local 09:00, occurrence revision participant snapshot, 32일 bounded source capture/sweep, exact-audience latest-state cancellation과 `calendar_event/calendar_occurrence` inbox·Android push pair를 `calendar-event-reminder.yaml.md`에 정의한다. payload는 family content를 포함하지 않으며 hosted scheduler·실제 Firebase·실계정·다중기기·실기기 증적은 마지막 Gate다.

WP05-08 Chore occurrence target recovery는 inbox와 재인가된 Android push의 strict subject UUID를 active household 권한으로 다시 확인한 뒤 `/chores/occurrence/:occurrenceId`의 authoritative 상세·기존 활동 내역으로 연결하는 경계를 `chore-occurrence-target-recovery.yaml.md`에 정의한다. direct target cache는 금지하고 missing·forbidden·deleted·skipped는 같은 unavailable 상태로 처리하며 실계정·실기기 tap 증적은 마지막 Gate다.

WP05-09 actionable Chore occurrence target은 기존 strict WP05-08 RPC를 N-1 client용으로 보존하면서 server-derived `canSetCompletion`을 포함하는 새 exact target read, 기존 versioned/idempotent 완료·다시 열기 mutation, 성공·충돌·응답 유실 뒤 authoritative reconciliation을 `chore-occurrence-target-actions.yaml.md`에 정의한다. direct action cache/outbox는 금지하고 실계정 role/assignment·두 기기 race·실기기 notification journey는 마지막 Gate다.

WP05-10 bounded Chore completion outbox는 Android Today/Chores 목록의 cached scheduled → completed 한 건만 exact auth subject/session/household/member/version/TTL/idempotency에 묶어 전용 encrypted fixed slot에 저장하고, foreground에서 authoritative target 권한을 다시 확인한 뒤 같은 명령만 재생하는 경계를 `chore-completion-outbox.yaml.md`에 정의한다. 완료 취소와 다른 mutation, notification target 상세 action은 계속 online-only이며 실제 Keystore·hosted membership·두 기기·실기기는 마지막 Gate다.

WP05-11 개인별 Calendar 알림 선행 시간은 정시·5·10·15·30·60분 전의 exact recipient preference, timed/all-day base instant 이후 lead→quiet-hours 순서, content-free source 유지, v1 12-key N-1 호환과 미평가 candidate만 원자적으로 재스케줄하는 경계를 `calendar-reminder-lead-time.yaml.md`에 정의한다. 이미 inbox 또는 terminal push 평가된 이력은 동결하며 복수 reminder·hosted provider·실계정·두 기기·실기기는 후속 Gate다.

WP05-12 Calendar notification Snooze는 active caller-owned Calendar inbox item의 5·10·30분, 연속 최대 3회와 occurrence 시작 후 1시간 bound, optimistic version·UUID command response-loss replay, 원본 inbox/pending push와 content-free replacement source의 원자적 교체, v1 inbox 호환과 exact v2 metadata를 `calendar-notification-snooze.yaml.md`에 정의한다. hosted provider·실계정·두 기기·실기기 timing은 마지막 Gate다.

WP05-13 개인별 Calendar 복수 사전 알림은 기존 기본 1개와 distinct fixed 추가 시간 최대 2개, v1 전체 보존·v2 기본-only 보존·strict 14-key v3, existing content-free source에 private lead identity를 둔 독립 latest-state/quiet-hours/inbox/Snooze/Android push 및 future-only reconciliation 경계를 `calendar-multiple-reminders.yaml.md`에 정의한다. arbitrary time/count·per-occurrence override와 hosted·실계정·두 기기·실기기는 후속 Gate다.

WP05-14 generic notification email fallback은 기본 OFF인 기존 category별 email preference, content-free source의 latest-state·quiet-hours·1시간 usefulness 재검사, address-free durable queue, confirmed Auth email의 service-claim-only 수명, fixed EN/KO SendGrid Web API payload와 submission ambiguity quarantine를 `notification-email-fallback.yaml.md`에 정의한다. hosted sender/domain/provider·실제 mailbox/account·두 기기·실기기는 마지막 Gate다.

WP05-16 Notification Center Realtime invalidation은 inbox insert/update, category preference insert/update, membership/household authorization 변화를 self-RLS 사용자별 generation 한 행으로 집계하고, exact 3-key content-free signal을 받은 현재 household 알림 센터가 first-page snapshot과 unread badge를 authoritative하게 다시 읽는 경계를 `notification-center-sync.yaml.md`에 정의한다. 전역 앱 셸 owner와 badge는 WP05-17에서 local automated scope로 연결했고 hosted·실계정·두 기기·suspended-process·실기기·provider 증적은 마지막 Gate다.

WP05-17 app-shell Notification Sync와 전역 badge는 인증 user/active household pair를 root lifecycle owner 하나에 묶고, route 이동에서는 snapshot·channel을 재사용하며 resume에는 channel 교체와 authoritative refetch를 수행하는 경계를 `notification-app-shell.yaml.md`에 정의한다. 가구·사용자·no-household 전환은 기존 content를 먼저 폐기하고 in-flight old-context 응답을 무시하며, Today·Chores·Calendar·Family·Settings가 같은 unread authority를 사용한다. hosted·실계정·두 기기·실기기·provider 증적은 마지막 Gate다.

WP02-08 Active Household Switching은 본인 current adult membership만 포함하는 7-key 목록, server-derived target member, optimistic selection version, same-target no-op, private content-free audit와 새 household 노출 전 household-bound local state 정리를 `active-household-switching.yaml.md`에 정의한다. Managed Child surface는 만들지 않으며 hosted·실계정·다중기기·실기기 검증은 마지막 Gate다.

WP02-09 Household Departure Handoff는 기존 leave transaction이 반환한 exact nullable fallback pair를 client authority로 소비하고, 별도 refresh 없이 household-bound local state를 purge한 뒤 fallback active 또는 no-household auth state를 commit하는 경계를 `household-departure-handoff.yaml.md`에 정의한다. Owner transfer와 server mutation은 변경하지 않으며 hosted·실계정·다중기기·실기기 검증은 마지막 Gate다.

WP02-10 Google identity 충돌 안전 복구는 Supabase Auth의 exact stable code 세 개만 `IDENTITY_CONFLICT`로 분류하고, 자동 병합·link 없이 Google local account selection을 best-effort 초기화한 뒤 사용자의 명시적 다른 계정 재시도와 enum-only support 경로를 `auth-identity-conflict-recovery.yaml.md`에 정의한다. email·provider identity·token·raw exception은 노출하지 않으며 hosted policy·실제 충돌 계정·다중기기·실기기는 마지막 Gate다.

WP02-11 초대 공유는 exact configured HTTPS `/invite/{token}` value object, Android `ACTION_SEND` text chooser의 native canonical 재검증, chooser-open 전용 성공 의미, 별도 명시적 write-only clipboard 복구와 raw credential process-memory 수명을 `invite-sharing.yaml.md`에 정의한다. 전달 완료를 추정하거나 실패 뒤 자동 복사하지 않으며 실제 share sheet·recipient·verified App Link·다중기기·실기기는 마지막 Gate다.

WP02-12 이메일 OTP 인증은 normalized email, exact 6자리 ASCII code, process-memory 10분 challenge와 60초 재전송 제한, strict matching session/user UUID 인계, 계정 존재 여부와 identity conflict를 숨기는 generic request 결과를 `email-otp-auth.yaml.md`에 정의한다. client identity link/merge와 email/code persistence·logging·analytics를 금지하며 hosted SMTP·identity policy, 실제 mailbox/account·다중기기·실기기는 마지막 Gate다.

WP02-13 앱 셸 세션 resume 재검증은 initial restore와 분리된 root foreground owner, single-flight와 bounded trailing refresh, 같은 사용자 active-household 재해석 및 새 context 노출 전 household-bound local purge를 `auth-session-resume-revalidation.yaml.md`에 정의한다. token·새 storage·telemetry를 추가하지 않으며 hosted revocation, 실제 계정·다중기기·BFCache·실기기는 마지막 Gate다.

WP06-02A subscription settings/paywall은 active-household server entitlement, Store-localized price/period, Owner/Admin household confirmation, pending/conflict/restore 상태, billing-owner 관리와 allowlisted policy/support link를 `subscription-settings.yaml.md`에 정의한다. Store result만으로 Plus를 열지 않으며 최종 가격·trial·limit과 실제 RevenueCat/Play 계정·sandbox·기기는 마지막 Billing Gate다.

WP08-04A Android 런타임 정책은 dev/prod별 최소 build·contract 호환 범위, emergency 전역 non-privacy mutation switch, exact public read, service-only versioned audit mutation, direct/Edge-forwarded user operation의 database-authoritative enforcement와 읽기·privacy/export 보존 경계를 `app-runtime-policy.yaml.md`에 정의한다. hosted 전파, N-1 signed binary, Play staged rollout과 실기기는 후속 Gate다.

WP08-04B capability 런타임 정책은 household, chores, calendar, notifications, profile, billing의 exact mutation switch, explicit table 분류, service-only expected-version audit, direct/Edge-forwarded DB enforcement, strict six-row Flutter snapshot과 다른 기능을 유지하는 localized partial-read-only UX를 `app-runtime-feature-policy.yaml.md`에 정의한다. cohort/percentage/per-account targeting, hosted 전파와 실계정·실기기 증적은 후속 Gate다.

WP01-08 Android platform capability registry는 notification delivery, Store billing, encrypted local storage, external links, background delivery의 exact provider/fallback composition snapshot과 알림 권한의 unsupported·denied·temporary local 상태 해석, Settings의 안전 대안 route를 `platform-capability-registry.yaml.md`에 정의한다. 이 화면은 provider/server health check나 WP08 mutation policy가 아니며 실제 Firebase·RevenueCat/Play·Keystore·system handler·실기기와 Web/iOS 검증은 후속 Gate다.

WP01-09 Android capability 자체 점검은 exact five snapshot을 준비됨·조치 필요·대안/제한으로 분할하고 `temporary issue → action required → fallback only → limited` 순서로 복구 계획을 만들며, 명시적 single-flight 알림 재확인을 기존 coordinator에 위임하는 경계를 `platform-capability-self-check.yaml.md`에 정의한다. 별도 permission prompt·system settings·Store/provider health probe를 만들지 않으며 실제 settings 왕복·provider·실계정·실기기는 마지막 Gate다.

WP01-10 privacy-safe analytics governance는 exact six typed event, exact five-field content-free envelope, 기본 OFF의 versioned device preference, Managed Child 선차단과 current no-behavioral-sink SDK inventory를 `analytics-governance.yaml.md`에 정의한다. Sentry operational reporting과 optional usage analytics를 분리하며 hosted provider·법률 동의·server consent record·실계정·실기기는 마지막 Gate다.

WP01-11 authenticated core primary navigation은 Today, Calendar, Family, Settings exact four route를 compact NavigationBar·medium collapsed rail·expanded extended rail에 동일 순서로 제공하고, `/chores`를 Today가 소유하는 push/back 보조 허브로, `/family`를 primary route로 정의한다. 기존 members alias 경계는 `core-primary-navigation.yaml.md`에 유지한다. 별도 state·storage·telemetry·DB/API를 추가하지 않으며 실제 계정·TalkBack·phone/tablet 실기기 검증은 마지막 Gate다.

| Markdown 문서 | 구현 시 생성할 원본 파일 | 역할 |
|---|---|---|
| `analysis_options.yaml.md` | `analysis_options.yaml` | analyzer/lint 최소 기준 |
| `analytics-governance.yaml.md` | `analytics-governance.yaml` | typed usage event allowlist·versioned device preference·child 선차단·SDK inventory 계약 |
| `account-deletion.yaml.md` | `account-deletion.yaml` | 앱 내 계정 삭제 요청·취소·worker·identity tombstone·Auth soft-delete 계약 |
| `auth-identity-conflict-recovery.yaml.md` | `auth-identity-conflict-recovery.yaml` | Google identity exact-code 충돌 분류·자동 병합 금지·다른 계정 재시도와 fixed support 복구 계약 |
| `auth-session-resume-revalidation.yaml.md` | `auth-session-resume-revalidation.yaml` | 앱 셸 foreground 세션 재검증·single-flight·authoritative household drift local 격리 계약 |
| `email-otp-auth.yaml.md` | `email-otp-auth.yaml` | 이메일 OTP request/verify·challenge 수명·anti-enumeration·session 인계와 secret 비보존 계약 |
| `app-runtime-feature-policy.yaml.md` | `app-runtime-feature-policy.yaml` | Android exact 6개 capability mutation switch·audit·DB enforcement·partial-read-only UX 계약 |
| `app-runtime-policy.yaml.md` | `app-runtime-policy.yaml` | Android 최소 build/contract·emergency read-only·direct/Edge mutation enforcement 계약 |
| `architecture-rules.yaml.md` | `architecture-rules.yaml` | 계층 의존 규칙 |
| `billing-assignment.yaml.md` | `billing-assignment.yaml` | 명시적 paid-household 선택·provisional binding·충돌·support remediation 계약 |
| `billing-feature-enforcement.yaml.md` | `billing-feature-enforcement.yaml` | lifecycle·versioned activation·aggregate gate·member/recurring-series 한도 집행 계약 |
| `billing-reconciliation.yaml.md` | `billing-reconciliation.yaml` | RevenueCat HMAC ingress·metadata inbox·leased subscriber refresh·retry/dead-letter 계약 |
| `chore-templates.yaml.md` | `chore-templates.yaml` | PII-free 앱 내 집안일 빠른 시작 catalog와 편집 가능한 기존 create 연결 계약 |
| `chore-occurrence-target-recovery.yaml.md` | `chore-occurrence-target-recovery.yaml` | Chore inbox/push strict subject 재인가·단건 authoritative 상세·안전한 recovery route 계약 |
| `chore-occurrence-target-actions.yaml.md` | `chore-occurrence-target-actions.yaml` | exact Chore target의 server-derived actionability·완료/다시 열기·멱등 재조정 계약 |
| `chore-completion-outbox.yaml.md` | `chore-completion-outbox.yaml` | Android 단일 scheduled 완료 intent의 encrypted 저장·foreground 재인가·bounded replay 계약 |
| `chore-series-cancel-from-occurrence.yaml.md` | `chore-series-cancel-from-occurrence.yaml` | 선택한 active scheduled occurrence의 server-derived recurrence slot 이후 미완료 취소·bounded terminal prefix 계약 |
| `chore-series-from-occurrence.yaml.md` | `chore-series-from-occurrence.yaml` | 선택한 active scheduled occurrence의 server-derived recurrence slot 이후 immutable 시리즈 수정 계약 |
| `core-primary-navigation.yaml.md` | `core-primary-navigation.yaml` | authenticated exact-four responsive navigation·route selected state·Today 소유 Chores 보조 허브 계약 |
| `guided-chore-advanced-recurrence.yaml.md` | `guided-chore-advanced-recurrence.yaml` | 첫 가구 exact-three guided 설정의 full recurrence 편집·fingerprint·secure v2 resume 계약 |
| `guided-chore-setup.yaml.md` | `guided-chore-setup.yaml` | 첫 가구에서 세 개 template chore를 순차·멱등 생성하는 guided activation 계약 |
| `guided-chore-setup-resume.yaml.md` | `guided-chore-setup-resume.yaml` | 제출된 guided exact-three batch의 secure checkpoint와 process-death 자동 재개 계약 |
| `household-activation-progress.yaml.md` | `household-activation-progress.yaml` | 역사적 성인 가구 activation milestone의 capped aggregate RPC와 Today 안내 계약 |
| `household-weekly-report.yaml.md` | `household-weekly-report.yaml` | 서버 파생 완료 주차의 bounded content-free aggregate·active member contribution·비차단 Today 계약 |
| `database-schema.sql.md` | `database-schema.sql` | 핵심 PostgreSQL schema 골격 |
| `domain-events.yaml.md` | `domain-events.yaml` | outbox/domain event 계약 |
| `diagnostic-report.yaml.md` | `diagnostic-report.yaml` | PII-safe local app/build/platform/incident report와 명시적 clipboard 계약 |
| `notification-inbox.yaml.md` | `notification-inbox.yaml` | category preference·quiet hours·durable inbox·read/badge·minimal payload 계약 |
| `notification-center-sync.yaml.md` | `notification-center-sync.yaml` | 사용자별 content-free 알림 센터 invalidation·full-refetch·stale·reconnect·권한 상실 계약 |
| `notification-app-shell.yaml.md` | `notification-app-shell.yaml` | 인증 앱 셸 단일 알림 owner·context purge·resume refetch·5개 주요 화면 전역 unread badge 계약 |
| `notification-endpoint.yaml.md` | `notification-endpoint.yaml` | 설치 identity·AES-GCM token binding·rotation·proof revoke·invalid-token cleanup 계약 |
| `notification-push.yaml.md` | `notification-push.yaml` | Android FCM source 평가·submission ambiguity·backoff/stale/SLO·최소 payload·permission/presentation/tap 재인가 계약 |
| `notification-worker.yaml.md` | `notification-worker.yaml` | leased Outbox resolution과 skip-locked inbox materialization·retry/dead-letter·pause/health 계약 |
| `one-time-chore-lifecycle.yaml.md` | `one-time-chore-lifecycle.yaml` | scheduled 단건 집안일의 이중 버전 update, soft-delete/cancel, immutable revision/audit와 idempotency 계약 |
| `one-time-chore-trash.yaml.md` | `one-time-chore-trash.yaml` | scheduled 단건 집안일의 process-memory Undo, bounded trash projection과 이중 버전 restore 계약 |
| `time-primitives.yaml.md` | `time-primitives.yaml` | Calendar local date/time·all-day·IANA timezone·DST resolution 계약 |
| `today-composition.yaml.md` | `today-composition.yaml` | Chore·Calendar source context 일치, 안정 정렬, 부분 실패와 stale 합성 계약 |
| `today-calendar-cache.yaml.md` | `today-calendar-cache.yaml` | Android Today Calendar encrypted fixed-slot 복구·read-only·invalidation 계약 |
| `calendar-sync.yaml.md` | `calendar-sync.yaml` | Calendar expected-version 복구, content-free Realtime invalidation, occurrence deep-link 계약 |
| `chore-sync.yaml.md` | `chore-sync.yaml` | Chore/Today content-free household invalidation, full-refetch·stale·reconnect·권한 상실 계약 |
| `calendar-overlap-preview.yaml.md` | `calendar-overlap-preview.yaml` | 같은 구성원 Calendar 겹침의 bounded read-only 미리보기와 저장 비차단 계약 |
| `calendar-advanced-recurrence.yaml.md` | `calendar-advanced-recurrence.yaml` | Calendar 생성·전체 시리즈 interval/end 편집, anchor 보존과 full-rule preview·retry 계약 |
| `calendar-weekly-weekdays.yaml.md` | `calendar-weekly-weekdays.yaml` | Weekly Calendar 복수 요일 선택·start-date anchor·ISO 직렬화·full-rule preview/retry 계약 |
| `calendar-monthly-anchor.yaml.md` | `calendar-monthly-anchor.yaml` | Monthly Calendar start-date 기준일 동기화·skip-not-clamp·full-rule preview/retry 계약 |
| `calendar-series-from-occurrence.yaml.md` | `calendar-series-from-occurrence.yaml` | 선택한 active scheduled non-exception Calendar occurrence 이후 source revision 변경·exception 보존 계약 |
| `calendar-series-cancel-from-occurrence.yaml.md` | `calendar-series-cancel-from-occurrence.yaml` | 선택한 Calendar recurrence slot 이후 moved exception 포함 취소·bounded terminal prefix 계약 |
| `calendar-series-cancellation-undo.yaml.md` | `calendar-series-cancellation-undo.yaml` | 선택 경계 Calendar 취소의 actor/version-bound 즉시 Undo·private pre-state 복원 계약 |
| `calendar-event-reminder.yaml.md` | `calendar-event-reminder.yaml` | Calendar occurrence 시작 알림의 시간·참여자 snapshot·bounded source·latest-state inbox/push 계약 |
| `calendar-reminder-lead-time.yaml.md` | `calendar-reminder-lead-time.yaml` | 개인별 Calendar 선행 시간·v1/v2 preference 호환·pending-only 재스케줄 계약 |
| `active-household-switching.yaml.md` | `active-household-switching.yaml` | 본인 가구 최소 목록·versioned active selection·local state isolation 계약 |
| `household-departure-handoff.yaml.md` | `household-departure-handoff.yaml` | 나가기 authoritative fallback·local purge·auth handoff 계약 |
| `data-export.yaml.md` | `data-export.yaml` | 개인 export 범위·JSON/TXT generation·private object·일회성 download·revoke/expiry purge 계약 |
| `household-privacy.yaml.md` | `household-privacy.yaml` | Owner shared-household export·one-time download·cooling-off deletion·retention/redaction/billing unlink 계약 |
| `invite-short-code.yaml.md` | `invite-short-code.yaml` | 짧은 초대 코드 hash-only 발급·TTL·lockout·generic preview/accept·process-memory continuation 계약 |
| `invite-sharing.yaml.md` | `invite-sharing.yaml` | Android native chooser·canonical invite URL·명시적 write-only clipboard 복구와 raw-token 수명 계약 |
| `legal-support-hub.yaml.md` | `legal-support-hub.yaml` | 앱 내 terms/privacy/support 접근·고정 HTTPS destination·문서 버전 authority·informational consent 계약 |
| `profile-preferences.yaml.md` | `profile-preferences.yaml` | 성인 profile/avatar preset·locale·개인/가구 IANA timezone·atomic version update 계약 |
| `platform-capability-self-check.yaml.md` | `platform-capability-self-check.yaml` | Android exact capability 집계·stable recovery plan·single-flight 알림 권한/기기 연결 재확인 계약 |
| `platform-capability-registry.yaml.md` | `platform-capability-registry.yaml` | Android exact 5개 platform provider·지원 상태·fallback과 Settings 상태 화면 계약 |
| `subscription-settings.yaml.md` | `subscription-settings.yaml` | server-authoritative 구독 상태·Store-localized paywall·restore/pending/conflict·관리/policy link 계약 |
| `web-companion-baseline.yaml.md` | `web-companion-baseline.yaml` | Web dev/prod build·path URL·runtime identity·no-PWA/no-persistent-cache·provider fallback 계약 |
| `web-invite-sharing.yaml.md` | `web-invite-sharing.yaml` | Web explicit `navigator.share`·canonical invite payload·manual clipboard recovery 계약 |
| `web-keyboard-focus.yaml.md` | `web-keyboard-focus.yaml` | Web keyboard-only navigation·visible focus·modal containment와 focus return 계약 |
| `web-route-recovery.yaml.md` | `web-route-recovery.yaml` | fixed continuation·session recovery·identity/household 격리·safe 404/unavailable 계약 |
| `edge-types.ts.md` | `edge-types.ts` | Edge Function TypeScript 의미 타입 |
| `env.example.md` | `env.example` | client public config와 server secret 경계 |
| `error-catalog.yaml.md` | `error-catalog.yaml` | 안정 오류 코드 |
| `openapi-edge.yaml.md` | `openapi-edge.yaml` | Edge Function HTTP 계약 |
| `pubspec.yaml.example.md` | `pubspec.yaml.example` | dependency category 예시 |
| `rls-contract.sql.md` | `rls-contract.sql` | RLS helper/대표 policy 계약 |
| `toolchain.json.md` | `toolchain.json` | Flutter/Dart/플랫폼/품질 기준 |
| `types.dart.md` | `types.dart` | Dart 의미 타입·오류·DTO 예시 |

## 변경 규칙

1. 계약 변경은 요구사항·결정·migration·test와 같은 PR에서 수행합니다.
2. 출시된 field/enum/error 의미를 바꾸지 않고 additive/deprecation 절차를 사용합니다.
3. 추출된 Dart/DB client와 OpenAPI/SQL drift를 CI에서 검사합니다.
4. 예시는 실제 secret, token, 이메일, 가족 콘텐츠를 포함하지 않습니다.
5. Flutter package patch 버전은 Phase 01에서 호환성 확인 후 lockfile에 고정합니다.
6. SQL/OpenAPI 계약은 클라이언트 편의를 위해 약화하지 않습니다.
7. Markdown 래퍼와 추출된 원본 파일의 내용이 다르면 Gate를 통과할 수 없습니다.
