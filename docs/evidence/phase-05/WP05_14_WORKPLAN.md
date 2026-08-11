# Phase 05 WP05-14 Generic Notification Email Fallback Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-10)** — `WP05_14_EVIDENCE.md`의 전체 local Gate가 통과했으며 hosted SendGrid·실제 mailbox/account·두 기기·실기기 Gate는 마지막 검증 단계로 유지한다.
- 수직 조각: existing content-free source → email preference/latest-state/quiet-hours → durable at-most-once queue → fixed SendGrid Web API adapter → generic EN/KO message → Flutter preference UI
- 요구사항: `WP05-14`, `FR-NOTIF-008`, `FR-NOTIF-003`–`006`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-I18N-01`, `D-022`, `D-023`, `D-044`, `D-069`
- 계약: `docs/contracts/notification-email-fallback.yaml.md`
- 예정 증거: `docs/evidence/phase-05/WP05_14_EVIDENCE.md`

## Product boundary

- 성인은 개인·가구·알림 category별로 확인된 account email에 generic fallback을 받을지 선택한다. 기본값은 OFF다.
- email은 durable inbox와 Android push와 독립이며 Web Push를 요구하지 않는다.
- 제목과 본문은 EN/KO fixed copy만 사용한다. 가구명, 구성원명, 집안일/일정 제목·설명·시각, subject ID, deep link/query를 넣지 않는다.
- 알림 주소를 화면에 표시하거나 DB delivery/evaluation/audit에 저장하지 않는다. provider 호출 직전 service-only claim에서 confirmed Auth email만 일시적으로 사용한다.
- marketing, digest, attachment, arbitrary template/content, unsubscribe list, Web Push, actual provider/domain/mailbox 검증은 범위가 아니다.

## Server and delivery contract

1. 기존 `notification_preferences.email` boolean과 v1/v2/v3 exact preference 계약을 그대로 사용한다.
2. candidate source마다 email evaluation과 최대 하나의 delivery를 생성한다. latest occurrence/recipient/preference를 evaluation과 claim 모두에서 재검사한다.
3. 기존 recipient quiet hours와 DST 정책을 적용하며 source schedule 뒤 최대 1시간 usefulness window가 지나면 보내지 않는다.
4. address가 없거나 확인되지 않았으면 provider 호출 없이 stable `NO_CONFIRMED_EMAIL`로 종결한다.
5. claim은 service role만 실행하며 raw address는 반환하지만 영속 table, transition, provider receipt, log, analytics 또는 evidence에는 남기지 않는다.
6. worker는 exact empty POST와 dedicated scheduler bearer만 허용하고 aggregate count만 응답한다.
7. SendGrid `POST https://api.sendgrid.com/v3/mail/send`, Bearer API key, exact one-recipient JSON을 사용한다. SDK/runtime dependency는 추가하지 않는다.
8. `202`는 accepted, explicit `429/5xx`는 bounded retry, invalid/auth/other rejection은 permanent다. submission marker 이후 network/parse ambiguity는 terminal quarantine한다.
9. optional provider message ID는 SHA-256만 저장하며 response body와 provider error는 읽거나 저장하지 않는다.
10. worker pause/rollback은 pending delivery를 보존하고 새 claim을 중단한다.

## Client design

- 기존 strict preference domain/repository/controller는 `email` 값을 이미 보존하므로 새 DTO/RPC version은 만들지 않는다.
- Notification Center category card와 editor에 email switch 및 verified-account/generic-content/inbox-fallback 설명을 추가한다.
- quick toggle과 dialog save 모두 다른 channel, quiet hours와 Calendar reminder set을 보존한다.
- EN/KO/EN-XA ARB, 48dp action, scrollable dialog와 200% text-scale reachability를 유지한다.

## DB/API impact

- forward migration: `supabase/migrations/20260810190000_notification_email_fallback.sql`
- private tables: `notification_email_evaluations`, `notification_email_deliveries`, `notification_email_delivery_transitions`, `notification_email_worker_control`
- service-only RPCs: `claim_notification_email_deliveries`, `mark_notification_email_submission_started`, `complete_notification_email_delivery`, `set_notification_email_worker_paused`
- new internal Edge Function: `notification-email-worker`
- server-only environment: `NOTIFICATION_EMAIL_WORKER_SECRET`, `SENDGRID_API_KEY`, `KINFLOW_NOTIFICATION_EMAIL_FROM`
- no public/client DB table, new user permission, provider SDK, persistent client cache, analytics property or event/source payload change.

## Automated evidence plan

1. exact private schema, constraints, grants, content/email-free persistence and one-source-one-delivery dedupe
2. default/disabled, unconfirmed address, confirmed address, category independence and inbox/push independence
3. latest-state suppression, preference-off cancellation, quiet-hours/DST, 1-hour expiry and source replay
4. lease concurrency, bounded retry schedule, completion replay, submission ambiguity, pause and stable transitions
5. Edge auth/method/body/config validation, exact claim/completion parser and aggregate-only output
6. SendGrid fixed endpoint/header/payload, generic EN/KO copy, 202/retry/permanent/ambiguous mapping and response-body non-read
7. Flutter quick/editor toggle preservation, localization and 200% accessibility
8. clean reset, focused/affected/full pgTAP, Node/Flutter full regression, analyzer/formatter/codegen/config/secret/docs/whitespace and Android dev APK

## Security and privacy

- public/anon/authenticated와 direct service table access를 모두 revoke하고, service role은 mediated RPC만 실행한다.
- queue·transition·provider hash에는 email, name, title, description, token, provider body, raw error 또는 free-form text가 없다.
- worker handler는 raw claim/provider exception을 응답·로그에 반영하지 않고 stable code/aggregate count만 사용한다.
- provider payload는 recipient address와 fixed sender/subject/text만 포함하며 household/member/source/subject/inbox ID를 custom argument로 보내지 않는다.

## Rollback

- server kill switch로 새 claim을 중지하고 client email switch를 숨기거나 false로 저장한다.
- 이미 accepted/ambiguous terminal history는 삭제·재전송하지 않고 pending/retry rows는 보존 또는 stable rollback cancellation한다.
- released client가 기존 email boolean을 계속 보내도 worker pause 상태에서는 provider I/O가 발생하지 않는다.
- provider 교체는 Edge adapter와 server secret만 forward change하며 preference/source schema는 유지한다.

## Completion boundary

- local deterministic DB/Edge/Flutter tests와 repository-wide automated Gate를 통과하면 WP05-14 local slice를 완료로 기록한다.
- hosted migration/scheduler, SendGrid sender authentication/reputation/quota, 실제 mailbox/account/spam-folder, 두 기기와 physical-device UX는 사용자 지시에 따라 기능 개발이 충분히 끝난 뒤 마지막 Gate에서 검증한다.
