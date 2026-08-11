# Phase 05 WP05-13 Per-user Calendar Multiple Reminders Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-10)** — 64-file/3,197-test DB, 1,360-test Flutter, repository Gate와 Android dev APK를 통과했으며 hosted/real-account/physical-device Gate는 마지막 검증 단계로 유지한다.
- 수직 조각: v3 Calendar preference → primary + two additional content-free sources → existing resolution/inbox/quiet-hours/Snooze/Android push path → strict Flutter editor
- 요구사항: `WP05-13`, `FR-NOTIF-012`, `FR-NOTIF-001`, `FR-NOTIF-003`–`006`, `FR-NOTIF-010`, `FR-NOTIF-011`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-019`, `D-020`, `D-022`, `D-023`, `D-064`, `D-067`, `D-068`
- 계약: `docs/contracts/calendar-multiple-reminders.yaml.md`
- 증거: `docs/evidence/phase-05/WP05_13_EVIDENCE.md`

## Product boundary

- 개인·가구별 Calendar 알림은 기존 기본 시간 1개와 선택적인 추가 시간 최대 2개를 가진다.
- 모든 시간은 기존 고정 어휘 `0/5/10/15/30/60`분이며 서로 달라야 한다. 추가 시간은 오름차순 canonical 배열로 저장한다.
- 각 선택 시간은 독립 알림으로 기존 durable inbox, quiet hours, Android push와 Snooze 경로를 통과한다. 알림 센터에는 가장 최근 항목 하나만 active로 남긴다.
- 설정 변경으로 새 시간이 이미 지난 occurrence를 소급 발송하지 않는다. 미평가 미래 source/resolution만 생성·재계산하고 평가 완료 이력은 동결한다.
- 임의 시간, 4개 이상, 일정별 override, category별 visible sensitive copy, iOS/APNs와 Web Push는 범위가 아니다.

## Server and compatibility contract

1. `notification_preferences.reminder_lead_minutes`는 v1/v2가 이해하는 기본 알림으로 유지한다. 새 Calendar-only `additional_reminder_lead_minutes integer[]`는 최대 2개, strict increasing, 기본과 distinct다.
2. preference v1 read/write exact 12-key는 새 필드를 노출하거나 삭제하지 않는다.
3. v2 read/write exact 13-key는 기본 알림만 노출한다. v2 쓰기는 추가 알림을 보존하며, 추가 값을 기본으로 승격한 경우 그 중복 값만 제거한다.
4. additive v3 read/write는 exact 14-key와 전체 알림 집합을 제공하고 기존 optimistic-version·identical no-op replay를 유지한다.
5. 기존 `calendar.occurrence_start_changed` event type과 exact 5-key content-free payload를 유지한다. private nullable `reminder_lead_minutes` source identity에서 null은 기본, integer는 추가 알림이다.
6. source unique identity에 internal lead를 포함해 같은 occurrence/version/audience의 각 선택 시간이 한 번만 생성된다.
7. resolver는 기본 source를 현재 기본 preference로 계산하고 추가 source는 저장된 explicit lead가 현재 추가 집합에 남아 있을 때만 actionable하게 한다. Snooze explicit schedule은 이 변경의 영향을 받지 않는다.
8. occurrence trigger와 32일 horizon sweep은 수신자별 현재 선택 집합을 생성한다. v3 설정 변경은 아직 미래인 새 source만 backfill하고, pending resolution/push만 재계산한다.

## Client design

- domain은 기본 1개, 추가 `0..2`개, fixed vocabulary, 기본과 distinct, strictly increasing을 강제한다.
- Supabase adapter는 v3 exact 14-key map과 실제 integer list만 허용하고 missing/extra/coerced field를 fail closed한다.
- repository와 controller는 전체 집합을 optimistic version과 함께 보존하며 다른 category를 교체하지 않는다.
- Calendar editor는 기본 dropdown과 추가 checkbox를 제공한다. 두 개가 선택되면 나머지 미선택 항목은 disabled되고 선택 해제는 계속 가능하다.
- 요약에는 기본과 추가 시간을 모두 표시하며 EN/KO/EN-XA ARB와 scrollable 200% text-scale 경계를 유지한다.

## Automated evidence plan

1. additive columns/checks/source unique identity, immutable source lead, grants와 v1/v2/v3 exact shapes
2. unauthenticated/cross-household, unsorted/duplicate/unsupported/over-limit/non-Calendar validation과 optimistic replay/conflict
3. v1 full preservation, v2 primary-only promotion and additional preservation, v3 full-set mutation
4. recipient별 1개 또는 3개 content-free source, independent schedule resolution, replay dedupe and existing worker processing
5. setting reconciliation: future-only addition, removed source latest-state suppression, pending primary/push movement, evaluated-history freeze
6. independent due materialization and one-current-inbox behavior, Snooze and single-lead regression
7. strict Flutter domain/DTO/repository/controller/UI/localization, compact 200% reachability, analyzer/formatter/codegen
8. clean reset, focused/affected/full pgTAP, full Flutter, config/secret/Node/workflow/docs/whitespace and Android dev APK

## DB/API impact

- forward migration: `supabase/migrations/20260810180000_calendar_multiple_reminders.sql`
- additive authenticated RPCs: `get_notification_preferences_v3`, `update_notification_preference_v3`
- additive preference column: `additional_reminder_lead_minutes`
- private source identity column: `app_private.chore_notification_outbox.reminder_lead_minutes`
- no new event type, Edge Function, provider field, permission, SDK, secret, analytics property or persistent client cache.

## Security and privacy

- RPC가 `auth.uid()`와 active household membership을 재검증하며 direct preference/source table writes와 private helper execution은 허용하지 않는다.
- source payload는 기존 exact 5-key metadata만 유지한다. lead identity도 private column이며 title, description, display name, email, token, provider result 또는 raw error를 포함하지 않는다.
- removed lead는 매 materialize/claim 전 latest-state resolver에서 다시 검사해 stale 처리한다.

## Rollback

- client는 v2로 복귀해 기본 알림만 편집할 수 있고 server는 추가 알림을 보존한다.
- v3 노출을 중단해도 이미 평가된 history는 유지하고 아직 전달되지 않은 source는 current preference/latest-state 정책으로 종료한다.
- released v3 client가 모두 retire되기 전에는 v3 RPC, additional preference/source identity를 제거하지 않는다.

## Completion boundary

- local deterministic DB/Flutter tests와 repository-wide automated Gate를 통과하면 WP05-13 local slice를 완료로 기록한다.
- hosted migration/scheduler, 실제 Firebase, 실계정, 두 기기 race, physical-device timing·permission·timezone/DST는 사용자 지시에 따라 기능 개발이 충분히 끝난 뒤 마지막 Gate에서 검증한다.
