# Phase 05 WP05-11 Per-user Calendar Reminder Lead Time Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-10)** — hosted/real-account/physical-device Gate는 마지막 검증 단계로 유지한다.
- 수직 조각: 개인별 Calendar preference → lead-adjusted latest-state resolution → pending inbox/push reschedule → strict Flutter settings UI
- 요구사항: `WP05-11`, `FR-NOTIF-010`, `FR-NOTIF-001`, `FR-NOTIF-003`–`006`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-019`, `D-020`, `D-022`, `D-023`, `D-064`
- 계약: `docs/contracts/calendar-reminder-lead-time.yaml.md`
- 증거: `docs/evidence/phase-05/WP05_11_EVIDENCE.md` (완료 시 생성)

## Product boundary

- 사용자는 가구별 자신의 `calendar_event` 알림을 정시, 5, 10, 15, 30, 60분 전 중 하나로 선택한다.
- 시간 지정 일정은 occurrence 시작 instant, 종일 일정은 가구 시간대 local date 09:00 instant에서 선택한 시간을 뺀다.
- quiet hours는 lead time을 적용한 reminder instant 이후에 계산한다. provider usefulness window도 이 reminder instant부터 기존 1시간을 유지한다.
- 같은 occurrence에 참여한 사용자마다 서로 다른 lead time을 사용할 수 있다.
- 변경은 아직 inbox 또는 push가 terminal evaluation되지 않은 reminder만 재계산한다. 이미 표시·발송·비활성·stale/no-endpoint로 평가된 기록은 철회하거나 재발송하지 않는다.
- 복수 reminder, category-specific sensitive copy, iOS/APNs와 Web Push는 범위가 아니다. bounded Snooze는 이 WP와 분리해 후속 WP05-12에서 구현했다.

## Server and compatibility contract

1. `public.notification_preferences.reminder_lead_minutes`는 `0, 5, 10, 15, 30, 60`만 허용하고 기본값은 `0`이다. `calendar_event`가 아닌 category는 반드시 `0`이다.
2. 기존 `get_notification_preferences(uuid)`와 `update_notification_preference(...)`의 이름, 인자, exact 12-field 결과를 유지한다. N-1 쓰기는 이미 저장된 Calendar lead time을 보존하고 신규 row에는 기본값 `0`을 사용한다.
3. Flutter는 exact 13-field `get_notification_preferences_v2(uuid)`와 lead 인자를 받는 `update_notification_preference_v2(...)`로 전환한다.
4. source event payload의 `scheduledAt`은 계속 base start/09:00 instant다. content-free outbox schema와 멱등 키는 변경하지 않는다.
5. latest-state resolver만 exact audience preference를 읽어 `base scheduledAt - lead`를 delivery `dueAt`으로 계산한다. source payload freshness 비교는 base instant와 계속 수행한다.
6. v2 update는 해당 사용자의 아직 평가되지 않은 future Calendar candidate resolution과 `pending` push evaluation을 원자적으로 새 reminder instant로 맞춘다.
7. inbox item이나 non-pending push evaluation이 존재하는 resolution은 immutable delivery history로 취급해 수정하지 않는다.
8. 인증, active household membership, optimistic version, RLS/grant, valid IANA timezone과 content-free payload 경계를 유지한다.

## Client design

- domain entity는 category별 lead invariant를 강제한다. Calendar는 허용 집합만, Chore category는 `0`만 허용한다.
- Supabase DTO는 v2 응답의 exact 13 keys와 integer lead를 strict parse한다. 누락, extra key, bool/double/string coercion은 거부한다.
- 알림 설정 dialog는 Calendar card에서만 lead selector를 제공한다. card summary와 editor help는 변경이 미발송 reminder에 적용됨을 EN/KO/EN-XA ARB로 알린다.
- 기존 channel, quiet-hours, timezone, optimistic version/conflict recovery와 runtime-policy mutation gate를 그대로 조합한다.
- 새 runtime dependency와 native permission은 없다.

## Automated evidence plan

1. column/default/check, private helper, v1/v2 function signatures, grants와 exact response keys
2. unauthenticated/cross-household rejection, invalid lead and non-Calendar non-zero rejection
3. default three-category v2 read, Calendar create/no-op/update/stale-version and N-1 write preservation
4. two participants on one occurrence receive different timed reminder instants
5. all-day 09:00 household-local base, DST-safe lead subtraction and quiet-hours ordering
6. pending resolution/evaluation atomic reschedule, evaluated/inbox history preservation
7. strict Flutter domain/DTO/repository/controller/UI parsing and localization regressions
8. focused/full pgTAP, DB reset/lint, focused/full Flutter, analyzer, formatter, localization/codegen, Node/config/secret/matrix/whitespace gates and Android dev APK

## DB/API impact

- forward migration: `supabase/migrations/20260810140000_calendar_reminder_lead_time.sql`
- additive column and v2 RPCs; existing public RPCs are retained unchanged for N-1 compatibility.
- no new table, outbox event, payload field, Edge function, provider contract, secret, analytics property or log field.

## Security and privacy

- preference is self-scoped through authenticated household membership and the existing RLS boundary.
- reminder resolution is per immutable audience member; another participant's preference cannot influence the current user's schedule.
- outbox, inbox, push payload, logs and evidence contain only existing identifiers and schedule metadata; title, description, display name, email, token and provider raw error remain forbidden.

## Rollback

- Flutter can return to v1 RPCs and omit the selector, which yields existing start-time behavior for default rows.
- server rollback is forward-only: use v2 to set Calendar leads to `0`, then deploy a migration that restores pending schedules before removing v2 APIs/column after N-1 retirement.
- do not drop the column or v2 functions while any released client may call them.

## Completion boundary

- deterministic local pgTAP and Flutter tests must prove personal isolation, strict compatibility and pending-only reschedule; full repository gates and Android APK must pass.
- Firebase delivery, hosted scheduler, real account, two-device race, physical notification permission and device timezone/DST evidence remain deferred by user direction until feature development is substantially complete.

## Local result

- exact recipient별 `0/5/10/15/30/60`분 Calendar lead, base-minus-lead 이후 quiet hours, 기존 1시간 usefulness window와 content-free source payload 경계를 구현했다.
- v1 exact 12-key read/write를 유지하면서 기존 lead 보존을 검증했고, Flutter는 strict 13-key v2 RPC와 Calendar-only selector를 사용한다.
- preference 변경은 미평가 future candidate와 pending push schedule만 원자적으로 이동시키며 inbox 또는 non-pending push 평가 이력은 동결한다.
- clean reset, focused/full pgTAP, focused/full Flutter, analyzer, formatter, localization/codegen/config/secret/Node/workflow/docs/whitespace와 Android dev APK Gate가 통과했다. 최종 수치는 `WP05_11_EVIDENCE.md`에 기록한다.
- 실제 Firebase·hosted scheduler·실계정·두 기기·실기기 timing은 사용자 지시에 따라 마지막 Gate로 유지한다.
