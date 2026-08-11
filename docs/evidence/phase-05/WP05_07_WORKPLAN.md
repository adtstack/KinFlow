# Phase 05 WP05-07 Calendar Event Reminder Work Plan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-09) / HOSTED·REAL-DEVICE GATE DEFERRED** — WP05/G5 전체 완료는 아님
- 수직 조각: Calendar occurrence/participant snapshot → content-free source event → latest-state resolution → durable inbox and Android push candidate → authenticated exact occurrence routing(WP05-08에서 후속 확장)
- 요구사항: `FR-NOTIF-001`, `FR-NOTIF-003`–`006`, `FR-CAL-001`, `FR-CAL-002`, `FR-CAL-004`–`006`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-019`, `D-020`, `D-022`, `D-023`
- 계약: `docs/contracts/calendar-event-reminder.yaml.md`
- 증거: `docs/evidence/phase-05/WP05_07_EVIDENCE.md`
- 로컬 결과: Calendar 집중 pgTAP 46/46, 관련 pgTAP 467, Node 140, Flutter 집중 49 및 전체 1,004 pass(+local-connectivity opt-in 1 skip), analyzer/lint/format/codegen 통과
- 실제 Firebase, hosted scheduler, 실계정, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- 시간 지정 일정은 occurrence 시작 시각에, 종일 일정은 해당 local date의 가구 시간대 09:00에 참여자별 reminder를 만든다.
- 종일 일정 자체는 instant로 변환하지 않는다. 09:00 instant는 notification scheduling에만 사용하며 event의 local date/exclusive end date 의미를 바꾸지 않는다.
- reminder 대상은 occurrence가 가리키는 immutable revision participant snapshot이다. one-time legacy revision만 current series participant를 fallback으로 사용한다.
- 반복 일정의 초기 1년 materialization이 알림 source event를 폭증시키지 않도록 insert capture는 32일로 제한하고, 기존 server worker batch가 bounded horizon enqueue를 먼저 수행한다.
- source event, inbox와 push payload에는 title, description, household/member display name, email과 provider credential을 포함하지 않는다.
- 사용자별 선행 시간과 복수 reminder, iOS/APNs, hosted scheduler와 실기기 provider 전송은 이 WP의 범위가 아니다. 개인별 선행 시간은 후속 WP05-11에서 구현한다.

## Server and data design

1. 기존 `app_private.chore_notification_outbox` 이름과 public worker RPC 이름은 배포 호환성을 위해 유지하되 event/aggregate/category/subject check를 Calendar까지 확장한다.
2. source event는 `audience_member_id`를 필수로 갖고 `(household, event type, occurrence, version, audience)`로 멱등화한다. 기존 Chore event도 exact audience로 backfill하고 reassignment가 due source를 갱신하도록 보강한다.
3. Calendar payload는 recipient member ID, local date, resolved reminder instant, timezone, status만 허용한다.
4. recurring/exception occurrence는 revision participant snapshot, one-time occurrence는 revision snapshot 부재 시 series participant를 사용한다. occurrence update는 이전·현재 snapshot의 합집합에 event를 기록해 제거된 참여자의 기존 delivery도 stale 처리한다.
5. generic latest-state resolver는 exact audience별 최신 version, schedule equality, series lifecycle, occurrence status, participant membership와 active auth member를 다시 검사한다.
6. suppressed resolution에도 immutable audience를 보존한다. inbox supersession은 그 audience에만 적용해 다른 Calendar 참여자의 같은 occurrence 알림을 취소하지 않는다.
7. future Calendar resolution은 due 이전에 inbox item을 만들지 않는다. push evaluation은 기존처럼 scheduled instant까지 대기하고 provider claim 직전 최신 상태를 다시 확인한다.
8. preference, resolution, inbox, push-delivery category/subject constraints와 mediated APIs는 `calendar_event/calendar_occurrence` pair를 허용하되 기존 Chore pair를 유지한다.

## Client design

- strict domain parser는 `calendar_event` category와 `calendar_occurrence` subject pair만 함께 허용한다.
- inbox와 push envelope는 기존 최소 식별자만 유지하고 category별 subject type을 canonical하게 직렬화한다.
- 알림 센터는 Calendar reminder category, generic latest household update 안내, 세 번째 preference card를 EN/KO/EN-XA로 표시한다.
- tap은 기존 authenticated target RPC와 active household wait를 통과한 뒤 exact Calendar occurrence route로 이동한다. stale/cancelled/mismatched target은 알림 센터로 fail closed한다(WP05-08 supersession).
- Android foreground/background visible copy와 channel 설명은 Chore 전용 표현을 제거하고 generic household reminder로 유지한다.

## Automated evidence plan

1. timed and all-day schedule resolution, exact content-free payload, 32-day insert bound and horizon enqueue idempotency
2. recurring revision participant fan-out and one-time participant fallback
3. reschedule, cancellation, series end and participant removal latest-state suppression
4. per-audience inbox materialization/cancellation isolation and future-due gating
5. Calendar preference default/update, strict RLS/grants and service-role enqueue boundary
6. push materialization/claim and authenticated target routing with the Calendar subject pair
7. Edge worker/push contract parsers accept only the new exact category/subject pair
8. Flutter domain/repository/controller/widget/push parser localization regressions
9. focused/full pgTAP, Node, Flutter, analyzer, format, codegen, localization, config, secret, matrix and whitespace gates

## Stop conditions and rollback

- title, description, display name, email, token material or raw provider response가 source/inbox/push envelope에 들어가면 배포하지 않는다.
- 한 참여자의 source event가 다른 참여자의 inbox item을 supersede하거나 취소하면 배포하지 않는다.
- 취소·일정 변경·참여자 제거 후 latest-state check가 이전 delivery를 허용하면 배포하지 않는다.
- 초기 반복 일정 하나가 전체 1년 × 참여자 수의 source event를 즉시 만들면 배포하지 않는다.
- rollback은 Calendar horizon enqueue를 중지하고 `calendar_event` category를 disable하는 forward operation으로 수행한다. 기존 Chore worker/push path는 유지한다.

## Non-scope

- multiple reminders, snooze and category-specific sensitive visible copy; user-selected lead time is the separate WP05-11 extension
- iOS/APNs and Web Push delivery
- hosted Supabase scheduler/dashboard/pager and Firebase project credentials
- real-account, remote migration, two-device, provider outage and physical-device evidence
