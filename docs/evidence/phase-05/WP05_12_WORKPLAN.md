# Phase 05 WP05-12 Calendar Notification Snooze Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-10)** — hosted/real-account/physical-device Gate는 마지막 검증 단계로 유지한다.
- 수직 조각: Calendar inbox item → bounded Snooze command → content-free source event → existing inbox/push workers → strict Flutter UI
- 요구사항: `WP05-12`, `FR-NOTIF-011`, `FR-NOTIF-003`–`006`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-018`, `D-019`, `D-022`, `D-023`, `D-048`, `D-067`
- 계약: `docs/contracts/calendar-notification-snooze.yaml.md`
- 증거: `docs/evidence/phase-05/WP05_12_EVIDENCE.md`

## Product boundary

- 알림 센터의 현재 Calendar 항목에서만 5분, 10분, 30분 뒤 다시 알림을 선택한다.
- 연속 최대 3회이며, occurrence 시작 기준 한 시간 이후로는 미룰 수 없다. 서버가 현재 시각과 occurrence 상태로 허용 가능한 최대 선택지를 계산한다.
- 성공 시 원본 알림은 즉시 목록과 unread badge에서 사라지고, 선택 시각이 되면 기존 durable inbox와 Android push 경로를 통해 새 알림이 나타난다.
- Chore 알림, 임의 분 입력, 영구 Snooze 기록 UI, 다중 reminder 설정은 범위가 아니다.

## Server and compatibility contract

1. 기존 `list_notification_inbox_items` v1 이름·signature·결과를 유지하고 additive v2가 `snooze_count`, `snooze_max_minutes`를 포함한 exact 16-field row를 반환한다.
2. `snooze_calendar_notification`은 authenticated caller, active household membership, exact recipient, current participant, Calendar scheduled occurrence와 optimistic item version을 다시 검증한다.
3. caller-generated UUID command는 advisory lock과 immutable private ledger로 직렬화한다. 동일 payload replay는 exact receipt를 반환하고 다른 payload collision은 거부한다.
4. 원본 inbox item의 read/cancel, authoritative unread count, 기존 pending push cancellation, 새 source event 생성과 receipt 저장은 한 트랜잭션이다.
5. 이미 terminal 평가·전송된 이력은 삭제하거나 다시 쓰지 않는다. source와 delivery의 pending/leased 상태만 stale/cancel로 전환한다.
6. 새 `calendar.occurrence_reminder_snoozed` payload는 exact 9-key content-free metadata만 가지며 command ID가 causation identity다.
7. 새 source는 기존 latest-state resolver, quiet hours, inbox materializer, Android endpoint와 reliable delivery worker를 재사용한다.
8. 명시적 Snooze 시각은 이후 Calendar lead preference 변경에 의해 이동하지 않는다.

## Client design

- domain은 `5/10/30`, count `0..3`, server maximum `0/5/10/30`과 exact receipt timing을 강제한다.
- Supabase adapter는 v2 inbox exact 16 keys와 command exact 9 keys를 실제 integer/UUID/UTC timestamp로 strict parse한다.
- controller는 temporary unavailable, invalid payload, unknown failure에 같은 command UUID를 보존해 response-loss replay를 안전하게 한다.
- 성공 시 원본 row를 제거하고 server unread count를 적용한다. terminal failure는 command UUID를 폐기하고 authoritative refresh 경로를 유지한다.
- 선택지는 scrollable bottom sheet, 성공 메시지는 text-scale-safe Snackbar로 제공하고 EN/KO/EN-XA ARB를 사용한다.

## Automated evidence plan

1. source event/payload/check/unique constraint, command ledger immutability, grants, v1/v2 signatures와 exact keys
2. unauthenticated, cross-household, non-recipient, stale version, inactive occurrence/participant, invalid choice, count/time bound rejection
3. original inbox/read/badge and pending push atomic cancellation, terminal history preservation
4. new source resolution, pre-due no materialization/claim, due inbox/push delivery, quiet-hours and lead-change immunity
5. same-key response-loss replay and different-payload collision
6. strict Flutter domain/DTO/repository/controller/runtime-policy/UI/localization and 200% text scale
7. clean reset, focused/full pgTAP, focused/full Flutter, analyzer, formatter, codegen/config/secret/Node/workflow/docs/whitespace and Android dev APK

## DB/API impact

- forward migration: `supabase/migrations/20260810170000_calendar_notification_snooze.sql`
- additive authenticated RPCs: `list_notification_inbox_items_v2`, `snooze_calendar_notification`
- private immutable table: `app_private.calendar_notification_snooze_commands`
- additive source event: `calendar.occurrence_reminder_snoozed`
- no new Edge Function, provider request field, native permission, SDK, secret, analytics property or persistent client cache.

## Security and privacy

- household UUID와 inbox UUID는 capability가 아니다. RPC가 `auth.uid()`, current active membership, recipient row와 participant snapshot을 서버에서 다시 확인한다.
- direct table write와 private helper/ledger execution은 허용하지 않는다.
- source, command ledger, tests와 UI telemetry에 title, description, household/member name, email, token, provider response 또는 raw error를 넣지 않는다.
- read/cancel과 replacement source emission이 원자적이므로 원본과 다시 알림이 동시에 active inbox로 남지 않는다.

## Rollback

- client는 action을 숨기고 기존 v1 inbox RPC로 복귀할 수 있다.
- server history는 삭제하지 않고 새 command 노출만 중단한다. 이미 생성된 source는 기존 worker 정책에 따라 완료시킨다.
- released v2 client가 모두 retire되기 전에는 v2 RPC, event type, ledger 또는 cancellation reason을 제거하지 않는다.

## Completion boundary

- local deterministic DB/Flutter tests와 repository-wide automated Gate를 통과하면 WP05-12 local slice를 완료로 기록한다.
- hosted migration/scheduler, 실제 Firebase, 실계정, 두 기기 race, physical-device notification timing·permission·timezone/DST는 사용자 지시에 따라 기능 개발이 충분히 끝난 뒤 마지막 Gate에서 검증한다.

## Local result

- fixed `5/10/30`분, count `1..3`, occurrence start+1h bound와 exact active recipient/participant/version authority를 구현했다.
- 원본 inbox/badge/pending push와 content-free replacement source를 원자적으로 교체하고 existing latest-state/quiet-hours/inbox/Android push worker 및 same-command response-loss replay를 검증했다.
- v1 inbox를 유지하고 strict 16-key v2 metadata, 9-key receipt, controller retry, fixed-choice EN/KO/EN-XA 200% UI를 연결했다.
- clean reset, focused/full pgTAP, focused/full Flutter, analyzer, formatter, localization/codegen/config/secret/Node/workflow/docs/whitespace와 Android dev APK Gate가 통과했다. exact 수치는 `WP05_12_EVIDENCE.md`에 기록했다.
- 실제 Firebase·hosted scheduler·실계정·두 기기·실기기 timing/permission/timezone/DST는 사용자 지시에 따라 마지막 Gate로 유지한다.
