# Phase 04 WP04-05 Today Composition Evidence

- Work Package: WP04-05 — Chore·Calendar Today composition, bounded paging, source-isolated stale/partial failure
- 기준 commit: base `a85f262`; implementation은 2026-08-07 현재 WP02-06/WP03/WP04 연속 workspace
- 검증일: 2026-08-07
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, Node 24.15.0
- 결과: **LOCAL AUTOMATED PASS / MASTER TODAY DETAIL ORDER·REALTIME·PERSISTENT OFFLINE·REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-05 | PASS FOR LOCAL AUTOMATED SLICE | 기존 Chore와 Calendar read model을 한 Today 화면에 합성하고 source별 loading, retry, refresh stale와 양방향 partial failure를 검증했다. |
| FR-TODAY-001 | IN PROGRESS | 두 source의 household, IANA timezone, server-local date와 member filter가 모두 일치할 때만 Calendar→Chore 순서로 합성한다. MASTER의 overdue→now/next→today chores→remaining events→completed collapsed 세분 순서는 남았다. |
| FR-TODAY-002 | IN PROGRESS | Everyone/Me가 Chore assignee server filter와 이미 인가된 Calendar participant projection을 함께 좁힌다. Managed Child P1과 실제 다중 계정 검증은 남았다. |
| FR-TODAY-003 | IN PROGRESS | 합성 화면에서도 기존 optimistic quick-complete, duplicate tap coalescing, rollback과 authoritative reconciliation을 유지한다. 실제 다중 client 검증은 남았다. |
| FR-TODAY-004 | IN PROGRESS | source별 마지막 성공 content/generated-at을 refresh 실패 중 유지하고 stale notice와 resume refresh를 제공한다. 영속 offline cache/outbox와 실기기 reconnect는 남았다. |
| FR-TODAY-005 | IN PROGRESS | Calendar initial/refresh 실패가 Chore를 숨기지 않고 Chore 실패도 Calendar를 숨기지 않으며 source별 retry가 독립 복구된다. Remote network fault 검증은 남았다. |
| FR-CAL-007 | IN PROGRESS | one-time/recurring/exception projection을 authoritative household-local Today에서 표시하고 Calendar 전체 화면 진입을 제공한다. Remote query plan과 두 기기 propagation은 남았다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR NEW LOCAL SURFACE | semantic section heading/event summary, en/ko/en-XA ARB와 combined Today 200% pseudo-locale overflow 회귀가 통과했다. 실제 보조기술과 tablet journey는 남았다. |
| NFR-REL-01 | PASS FOR NEW READ SLICE | page size 100, Today 검사 상한 500, stable ordering, cursor/context/duplicate fail-closed, refresh content retention과 latest-filter-wins를 자동 검증했다. |

## Composition Contract

- Chore authority는 `get_chore_list(..., p_view => 'today')`, Calendar authority는 `get_calendar_event_page_v2(..., p_view => 'agenda', null range)`다. Today는 별도 저장 source가 아닌 두 authoritative read model의 화면 합성이다.
- 두 RPC가 돌려준 household id, household timezone, server-derived household-local date와 Everyone/Me filter가 exact match일 때만 combined snapshot을 만든다. client clock은 day boundary에 사용하지 않는다.
- Calendar는 100개씩 keyset page를 읽고 첫 future household-local projection, `has_more = false`, 또는 검사한 Today event 500개에서 중지한다. 상한에서 남은 row 가능성이 있으면 truncated notice를 표시한다.
- Calendar projection은 all-day 우선, household view-local time, occurrence id tie-break 순서를 유지한다. duplicate occurrence, 역순 page, cursor/range/context drift는 invalid payload로 fail closed한다.
- Me는 서버가 이미 household membership으로 인가한 Calendar projection에서 participant membership을 추가로 좁힌다. Chore는 기존 server assignee filter를 사용하며 어느 쪽도 권한을 확장하지 않는다.
- source refresh 실패는 마지막 성공 snapshot과 generated-at을 보존한다. 다른 source는 계속 표시되고 retry는 실패한 source만 다시 읽는다.
- 같은 query의 중복 load는 coalesce하고 다른 member filter가 진행 중 load를 대체하면 request generation으로 늦게 도착한 이전 응답을 폐기한다.

## Flutter Vertical Slice

- platform-free `TodayCalendarRequest`, `TodayCalendarSnapshot`, `TodaySnapshot`이 source context, participant boundary, maximum size, identity와 total order invariant를 소유한다.
- `TodayCalendarController`는 bounded agenda paging, Me participant filtering, strict page continuity, initial/refresh state와 retained stale snapshot을 제공한다.
- auto-dispose Riverpod provider는 기존 `CalendarRepository` adapter만 조합한다. 새 SDK, network client 또는 persistence를 추가하지 않았다.
- 기존 Today Chore screen은 Today view에서 두 source를 동시에 load/refresh한다. Upcoming, Overdue, Completed view는 기존 Chore-only 동작을 유지한다.
- Calendar section은 all-day/timed/현재 진행, participant, recurring/exception metadata, loading/empty/stale/truncated/error와 Calendar 화면 진입을 ARB 문자열로 표시한다.
- Chore quick-complete 뒤 Calendar section은 유지되고 Chore controller의 optimistic mutation과 server reconciliation 경계는 변경하지 않았다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| focused Today domain/controller/widget | PASS, 15/15 |
| affected app/Chore/household/Today regression | PASS, 71 tests included in full suite |
| full Flutter regression | PASS, 447 tests + local-connectivity opt-in 1 skip |
| full Flutter coverage | PASS, 9,701/12,193 lines, 79.56% |
| exact formatter/analyzer | PASS, 265 files changed 0; fatal infos/warnings 포함 analyzer issue 0 |
| exact dependency replay | PASS, `flutter pub get --enforce-lockfile --offline`; lockfile SHA-256 `23be7be55bef306c8c5423873047bee3dd7c9c2e7a5d1265f7d9ae241e279ba5` 유지 |
| localization/codegen | PASS, en/ko/en-XA generated drift 0/8 files |
| public config/secret scan | PASS, public config exact allowlist; high-confidence secret 0 |
| whitespace | PASS, tracked diff와 WP04-05 신규 파일 trailing whitespace 0 |
| database regression | NOT RUN BY DESIGN, migration/RPC 변경 없음; WP04-04C의 clean 23-migration reset과 1,527 pgTAP baseline 의존 |

Focused fixtures는 exact source context 합성, stable section/event order, local-date와 member-filter mismatch, participant boundary, server-local default agenda request, cursor continuation과 future-date stop, 500-row cap/truncated disclosure, retained refresh failure, malformed server day, late previous-filter response suppression, 양방향 partial failure/retry, combined quick-complete, Everyone/Me dual-source narrowing과 200% pseudo-locale layout을 포함한다.

## Files and Contract Surfaces

- Today domain/application/provider/widget: `apps/kinflow_app/lib/features/today/`
- Composition host and existing Chore actions: `apps/kinflow_app/lib/features/chores/presentation/screens/today_chores_screen.dart`
- Localization: `apps/kinflow_app/lib/l10n/app_en.arb`, `app_ko.arb`, `app_en_XA.arb`와 generated localizations
- Focused tests: `apps/kinflow_app/test/features/today/`
- Updated harnesses: app shell, adaptive accessibility, Chore and household widget tests에 deterministic empty Calendar source 주입
- Contract: `docs/contracts/today-composition.yaml.md`
- Database/migration: **변경 없음**

## Security, Privacy, and Data

- 두 source는 기존 authenticated RLS/security-definer boundary와 strict Supabase adapter를 그대로 사용한다. Today layer는 repository가 인가한 typed projection만 받는다.
- cross-household, mixed date/timezone/filter 또는 malformed paging payload는 합성하지 않는다. 유효한 다른 source content만 유지한다.
- event title, description, participant name 또는 chore content를 새 저장소, log, analytics나 operational state에 복제하지 않는다. raw provider exception도 UI에 표시하지 않는다.
- persistent cache, background task, native permission, OS Calendar access, runtime dependency와 analytics event를 추가하지 않았다.
- 자동 검증은 synthetic UUID/name/event만 사용했고 production project, 실제 계정, token 또는 고객 데이터를 사용하지 않았다.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 성인 계정, 실제 household, 성인 2계정·두 기기, Android/iOS 실기기 검증은 **NOT RUN**이다.
- remote Supabase migration/query plan, production-size Today p75/p95, network loss/throttle와 true midnight race는 **NOT RUN**이다.
- device timezone travel, actual locale/date rendering, VoiceOver/TalkBack, tablet/split layout와 background/resume는 **NOT RUN**이다.
- persistent offline cache/outbox와 action별 offline disable policy는 **NOT IMPLEMENTED / NOT RUN**이다.
- Realtime reconnect, stale expected-version conflict와 multi-client propagation은 **NOT IMPLEMENTED / NOT RUN**이며 WP04-06 범위다.

## Remaining Risks and Completion Boundary

1. 현재 combined view는 Calendar section 뒤 Chore section의 안정 순서를 제공하지만 MASTER의 overdue, now/next, due-today, remaining event, completed-collapsed 다섯 구간을 한 Today feed로 재배치하지 않았다.
2. Today 전용 aggregate API가 아니라 기존 두 RPC를 client에서 병렬 조합한다. 원격 cardinality와 latency 측정 전에는 NFR-PERF-01을 시작 또는 통과로 표시하지 않는다.
3. Calendar Me filter는 인가된 household page를 client에서 최대 500개까지 검사한 후 participant로 좁힌다. 권한은 확장하지 않지만 대형 가구에서 server-side filter보다 비용이 크다.
4. stale content는 provider 생명주기 안의 마지막 성공 snapshot이다. process restart 후 offline read나 mutation outbox는 없다.
5. Calendar mutation 뒤 Today route 재진입/refresh는 authoritative reload하지만 다른 기기의 즉시 반영은 WP04-06 Realtime까지 보장하지 않는다.
6. 따라서 WP04-05 local automated slice만 완료하며 FR-TODAY 전체, Phase 04, release gate와 장기 기능 목표는 `IN_PROGRESS/PARTIAL`을 유지한다.

## Rollback

- production 적용 전에는 `features/today`, Today screen composition, 새 ARB/generated strings, test overrides와 contract/evidence를 함께 revert해 WP03-06 Chore-only Today로 돌아간다.
- DB migration이나 새 persisted data가 없으므로 data rollback은 없다. Calendar 화면과 Chore mutations는 독립적으로 계속 동작한다.
- 운영 중 Calendar source 문제가 생기면 Today Calendar section/provider만 숨기고 Chore-only Today를 유지할 수 있다.

## Next Entry Condition

- 다음 기능 우선순위는 WP04-06 expected-version conflict와 Realtime reconnect/full refetch다.
- mutation 성공/충돌/삭제/재연결이 현재 route와 Today/Calendar read model을 정확히 무효화하고 source별 stale state를 안전하게 해소해야 한다.
- 그 이후 MASTER Today 다섯 구간 UX, server-side participant filter 또는 aggregate endpoint, persistent offline 정책과 performance profiling을 별도 slice로 닫는다.
- 실계정·remote·실기기 gate는 사용자 지시에 따라 기능 개발 후 마지막 단계로 유지한다.
