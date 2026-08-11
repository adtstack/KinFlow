# Phase 04 WP04-13 External Calendar File Import Work Plan

## Status

- 상태: **LOCAL AUTOMATED SLICE PASS (2026-08-09)** — WP04/G4 완료는 아님
- 수직 조각: Android document picker → strict bounded RFC 5545 parser → selectable preview → active-household participants → existing idempotent one-time/recurring create RPCs → Calendar refresh
- 요구사항: `FR-CAL-009`, `FR-CAL-001~004`, `NFR-SEC-01`, `NFR-PRIV-01`, `NFR-REL-01`, `NFR-A11Y-01`, `NFR-I18N-01`, `D-059`
- 계약: `docs/contracts/calendar-file-import.yaml.md`
- 증거: `docs/evidence/phase-04/WP04_13_EVIDENCE.md` (검증 후 작성)
- 실제 provider 계정, hosted Supabase, 두 기기와 physical-device 검증은 사용자 지시에 따라 마지막 Gate로 유지한다.

## Product boundary

- Android 사용자가 Storage Access Framework로 직접 고른 UTF-8 `.ics` 파일만 process memory에서 읽고, 지원 일정과 건너뛴 수를 확인한 뒤 선택한 항목을 현재 가구로 복사한다.
- 파일은 256 KiB, VCALENDAR 하나, VERSION 2.0 하나, VEVENT 최대 50개로 제한한다. file URI, 원문, display name, UID는 log·cache·database·analytics에 저장하지 않는다.
- all-day, UTC·floating·IANA TZID timed event와 기존 KinFlow daily/weekly/monthly recurrence subset만 수용한다. unsupported event는 일정 단위로 건너뛰고 구조/encoding/size 오류는 파일 전체를 거부한다.
- 한 batch는 공통 active-household participant 1~50명을 사용한다. 기본값은 현재 구성원이다.
- import는 sync가 아닌 새 일정 복사다. 같은 파일을 다시 고르면 중복될 수 있고 외부 변경·삭제는 전파되지 않는다.
- Google/Apple/CalDAV 계정, calendar permission, broad storage permission, background sync, DB/API/RLS/migration은 범위 밖이다.

## Domain and application design

1. pure Dart parser가 content-line unfolding, parameter/value delimiter, RFC TEXT escape, DATE/DATE-TIME/DURATION과 exact supported RRULE을 typed candidate로 만든다.
2. parser는 raw UID를 같은 파일 안 중복 확인에만 쓰고 결과 candidate에서 제거한다. unknown display-only property는 실행하지 않고 버린다.
3. timed start/end는 existing `CalendarTimeResolver`로 검증해 DST gap·unknown zone을 skip하고 instant 차이에서 positive minute duration을 계산한다. floating time은 household timezone, overlap은 existing earlier policy를 쓴다.
4. controller는 picker cancellation/unavailable/fatal parse/preview/importing/partial failure/completed를 명시적 상태로 분리한다.
5. import 시작 전에 selection·participants·draft와 candidate별 command ID를 freeze한다. repository는 preview 순서로 하나씩 호출하고 첫 실패에서 멈춘다. retry는 실패한 동일 command ID로 이어간다.
6. runtime Calendar mutation policy는 picker, parser, command ID와 repository보다 먼저 검사한다. 성공 뒤 process source를 버리고 Calendar를 새로 읽는다.

## Presentation design

- Calendar header에 create와 구분되는 import action을 추가하고 `/calendar/import` route에서 파일 선택 안내를 제공한다.
- preview는 파일명, supported/skipped 수, floating/overlap·ignored-fields·duplicate-copy disclosure와 각 일정의 title/date/time/recurrence를 표시한다.
- 일정 checkbox와 active member checkbox는 48dp target을 사용하며 0개 선택·0명 participant일 때 import를 비활성화한다.
- importing progress, first-failure partial count, same-batch retry, cancellation, unsupported-only file과 successful count를 EN/KO/EN-XA ARB로 표시한다.
- compact 320×568, EN-XA 200%에서 scroll/wrap과 blocker overflow를 자동 검증한다.

## Automated evidence plan

1. RFC line folding/TEXT escapes, CRLF/LF, exact VCALENDAR/VERSION and size/event bounds
2. all-day implicit/exclusive end and day/week duration; UTC/floating/TZID timed start/end/duration
3. DST gap skip, overlap earlier, zone/value mismatch, seconds, malformed/duplicate properties and unsupported-component aggregation
4. daily/weekly/monthly interval/count/all-day until mapping plus unsupported recurrence rejection
5. MethodChannel exact selected/cancelled/unavailable/failure/malformed/oversize mapping and no URI contract
6. controller selection/participants, one-time+recurring order, no-I/O invalid/runtime-disabled, first-failure stop and same-key retry
7. route and widget empty/pick/preview/import/partial/retry/success plus EN/KO/EN-XA compact 200%
8. Android dev debug compile, full Flutter tests, fatal analyzer, exact format/codegen/config/secret/docs/whitespace gates

## Stop conditions and rollback

- parser가 timezone/recurrence meaning을 추정하거나 unsupported property를 실행하면 배포하지 않는다.
- file/UID/content가 log·persistent cache·analytics·RPC metadata에 포함되면 배포하지 않는다.
- runtime policy 이전 picker/command/network I/O, participant 없는 write, partial failure 뒤 새 retry key가 발생하면 배포하지 않는다.
- Android manifest에 calendar 또는 broad storage permission이 추가되면 배포하지 않는다.
- rollback은 import action/route, native channel, gateway/parser/controller/UI를 함께 제거한다. server rollback은 없다.

## Non-scope

- external account sign-in, provider API, two-way or background sync
- persisted UID mapping/dedup/update/delete propagation
- VTIMEZONE custom rules, recurrence exception, yearly/ordinal/business-day rules
- iOS/Web picker, hosted/provider/real-account/multi-device/physical-device evidence
