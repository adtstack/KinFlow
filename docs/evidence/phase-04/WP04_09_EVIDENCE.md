# Phase 04 WP04-09 Persistent Today Calendar Cache Evidence

- Work Package: WP04-09 — Android encrypted Today Calendar cold-process cache
- 기준 commit: base `a85f262`; implementation은 2026-08-09 현재 연속 workspace
- 검증일: 2026-08-09
- 환경: macOS arm64, Flutter 3.44.7 stable, Dart 3.12.2
- 결과: **LOCAL AUTOMATED PASS / REMOTE·REAL-ACCOUNT·REAL-DEVICE DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP04-09 / FR-TODAY-004 / D-017 | PASS FOR LOCAL AUTOMATED SLICE | Android의 기존 environment-scoped encrypted read-cache에 `today_calendar_v1` fixed slot을 추가했다. online에서 완전히 검증된 Today Calendar snapshot만 저장하고 initial `temporarilyUnavailable`일 때 process-restart snapshot을 cached-at/read-only로 복원한다. |
| FR-TODAY-001 / NFR-REL-01 | PASS FOR STRICT SNAPSHOT | household, timezone, server-local date, server `generatedAt`, exact member filter, truncation과 최대 500 canonical projection을 보존한다. timed/all-day/recurring/exception/empty payload를 domain constructor로 다시 검증하며 duplicate, out-of-order와 corrupt context는 삭제하고 fail closed한다. |
| D-049 / NFR-SEC-01 | PASS FOR LOCAL IDENTITY BOUNDARIES | 기존 exact user/session/household/TTL envelope를 재사용한다. authorization loss는 전체 read cache를 clear하고 logout/no-household는 기존 purge를, household transition은 mismatched Calendar slot 삭제를 수행한다. |
| FR-CAL-001~007 | PASS FOR LOCAL INVALIDATION | one-time create/update/delete, recurring create, series update/cancel, occurrence update/cancel의 8개 성공 경로가 Today Calendar slot을 invalidate한다. transient mutation failure는 valid cache를 유지하고 authorization failure는 모든 read slot을 clear한다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION | EN/KO/EN-XA ARB에 cached-at, read-only 이유와 retry를 추가했다. cached event와 empty cached snapshot 모두 disclosure를 유지하고 Today view/Everyone-Me filter를 authoritative recovery 전까지 비활성화한다. 320×568 EN-XA 200% widget 회귀가 통과했다. |

`FR-TODAY-004`의 Android local automated 범위는 통과했다. 실제 Keystore process
death, airplane mode, remote membership removal, background Realtime, Web offline와
실계정·실기기 검증은 실행하지 않았으므로 요구사항 전체 상태는 `PARTIAL`로 유지한다.

## Storage and Composition Contract

- 새 key는 identifier와 content를 포함하지 않는 고정 `today_calendar_v1`이다.
- 기존 `SecureReadCache`의 exact seven-key envelope, authenticated user/session,
  expected household, session expiry 이하 최대 24시간 TTL과 196,608 encoded-byte
  한도를 그대로 사용한다.
- payload는 version 1 exact map이며 household ID/timezone/local date, server
  `generatedAt`, optional participant member filter, truncation과 projection list만 가진다.
- projection과 event도 exact key set을 요구한다. 모든 identifier/time primitive,
  participant, recurrence와 exception field는 기존 value object와
  `OneTimeCalendarEvent.tryCreate`, `CalendarEventProjection.tryCreate`,
  `TodayCalendarSnapshot.tryCreate`를 다시 통과해야 한다.
- valid하지만 다른 Everyone/Me filter snapshot은 표시하거나 삭제하지 않는다. corrupt,
  duplicate, out-of-order, another-household 또는 authoritative timestamp mismatch는 해당
  slot을 삭제한다.
- normative 계약은 `docs/contracts/today-calendar-cache.yaml.md` v1과
  `docs/contracts/today-composition.yaml.md` v3다.

## Client Behavior

- Today Calendar online load가 모든 bounded page와 context를 검증한 뒤 server
  `generatedAt`을 validation timestamp로 snapshot을 best-effort 저장한다. superseded
  generation은 저장하거나 표시하지 않는다.
- initial failure가 `temporarilyUnavailable`일 때만 exact cache를 조회한다. retained
  in-memory content는 기존 stale behavior를 유지하며 not-found/forbidden과 invalid
  payload는 cached fallback을 사용하지 않는다.
- cached state는 event가 있거나 비어 있어도 마지막 동기화 시각, read-only 이유와
  retry를 표시한다. Calendar를 포함한 Today source context가 stale인 동안 Today
  view와 Everyone/Me 변경을 막는다.
- retry 성공은 authoritative snapshot으로 교체하고 cache marker/refresh failure를
  제거한다. cache 저장 오류는 online authoritative content를 숨기지 않는다.
- event route에는 occurrence UUID만 전달하며 cached title/description/participant를
  route, log 또는 analytics에 복제하지 않는다.

## Mutation and Lifecycle Invalidation

- `TodayCacheInvalidatingCalendarRepository`가 모든 Calendar read를 그대로 delegate한다.
- 다음 성공만 `today_calendar_v1`을 삭제한다: one-time create/update/delete, recurring
  create, series update/cancel, occurrence update/cancel.
- temporary/validation/conflict failure는 성공으로 가장하거나 valid cache를 지우지
  않는다. retained content를 무효화하는 authorization failure는 전체 encrypted read
  cache를 clear한다.
- Android persistent-cache composition에서만 decorator와 snapshot adapter를 같은
  `SecureReadCache` instance에 연결한다. unavailable/Web 경로는 기존 repository와
  no-op cache를 유지한다.
- household replacement은 active household를 쓰기 전에 Calendar fixed slot도 expected
  household로 probe해 mismatched old data를 제거한다. logout/account/session purge는
  기존 sensitive-local-state participant를 재사용한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| strict Calendar snapshot codec | PASS, 7/7: full variant/empty round-trip, filter preservation, unknown field, duplicate/order, household, timestamp rejection |
| mutation decorator | PASS, 3/3: 8 success invalidations, transient preservation, authorization clear |
| Today controller | PASS, online write, cold-process fallback, retry replacement, authorization purge와 기존 paging/race/sync 회귀 |
| Today composition widget | PASS, cached event/empty disclosure, read-only filters, recovery와 EN-XA 200% |
| focused cache + composition suite | PASS, 18/18 |
| full Flutter regression | PASS, 848 tests + local-connectivity real-environment opt-in 1 skip |
| exact analyzer | PASS, issue 0 (`--no-pub --fatal-infos --fatal-warnings`) |
| exact formatter | PASS, 522 files / changed 0 |
| localization/codegen drift | PASS, 8 generated files current; build runner wrote 0 outputs |
| public config | PASS, exact public allowlist |
| secret scan | PASS, high-confidence finding 0 |
| database/Edge regression | **NOT RUN BY DESIGN**; migration, DB object, RLS, RPC/Edge signature와 backend source 변경 없음 |

실행한 핵심 명령은 다음과 같다.

```text
flutter gen-l10n
flutter test --no-pub test/infrastructure/read_cache_today_calendar_snapshot_cache_test.dart test/features/today/today_composition_widget_test.dart
flutter test --no-pub --reporter compact
flutter analyze --no-pub --fatal-infos --fatal-warnings
dart format --output=none --set-exit-if-changed lib test tool
dart run tool/verify_codegen.dart
dart run tool/validate_public_config.dart
dart run tool/scan_secrets.dart
git diff --check
```

## Files and Data Impact

- Cache application port/state/controller:
  `apps/kinflow_app/lib/features/today/application/today_calendar_snapshot_cache.dart`,
  `today_calendar_controller.dart`, `today_calendar_state.dart`
- Strict infrastructure and mutation policy:
  `apps/kinflow_app/lib/infrastructure/cache/read_cache_today_calendar_snapshot_cache.dart`,
  `today_cache_invalidating_calendar_repository.dart`
- Runtime composition/lifecycle: `read_cache.dart`, `auth_dependencies.dart`,
  `bootstrap.dart`, `today_providers.dart`, `cached_household_data_source.dart`
- UI/localization: `today_calendar_section.dart`, `today_chores_screen.dart`, EN/KO/EN-XA
  ARB와 generated localizations
- Tests: snapshot codec, repository invalidation, Today controller/composition widget,
  secure fixed-slot purge, household transition과 auth composition
- Contract/tracking: Today Calendar cache v1, Today composition v3, Phase 04 workplan,
  requirement/test/risk matrices, changelog와 이 evidence

새 migration, table, index, RLS, RPC/Edge signature, runtime dependency, native permission,
analytics 또는 log event를 추가하지 않았다. server data rollback도 필요하지 않다.

## Security, Privacy, and Data

- Calendar schedule content는 Android Keystore-backed AES-GCM secure-storage namespace
  안에서만 영속화되며 plaintext fallback과 backup migration은 disabled다.
- storage key는 user/session/household/member/content를 포함하지 않는다. envelope와
  payload 모두 read 시 exact identity/context/domain validation을 통과해야 한다.
- title, description과 participant name은 authorized projection의 encrypted payload와
  render state에만 존재한다. raw cache/provider exception이나 content를 새 log,
  analytics, route 또는 error copy에 넣지 않았다.
- cache-only state는 mutation authority가 아니며 offline outbox를 만들지 않는다.
  source query를 바꾸려면 먼저 authoritative reconnect/refresh가 필요하다.
- 자동 검증은 fake secure storage와 synthetic household/event만 사용했고 production
  project, 실제 계정, token 또는 고객 데이터에 접근하지 않았다.

## Defect Found During Validation

empty cached Calendar snapshot이 valid해도 기존 whole-Today empty branch가 Calendar
source status widget을 생략해 cached-at/read-only 이유가 보이지 않는 누락을 신규
EN-XA 200% test가 발견했다. empty branch에도 동일한 Calendar section을 연결해 online
empty에서는 숨고 cached/stale/disconnected 상태에서만 disclosure와 retry가 표시되도록
수정했으며 targeted 및 full regression으로 재검증했다.

## Manual and Deferred Validation

사용자 지시에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**로 유지한다.

- 실제 Android Keystore에서 196,608-byte 경계의 write/read latency와 low-memory 상태
- app force-stop/process death 뒤 airplane mode cold launch와 session-expiry 경계
- 실제 Google/Supabase 계정의 logout/account switch/household switch cache forensic
- remote membership removal 또는 RLS revoke와 cached content 즉시 폐기
- 자정·DST·device timezone travel 중 서로 다른 Chore/Calendar server-local date 처리
- Realtime background/resume/reconnect와 두 기기 mutation propagation
- TalkBack, 실제 200% font, keyboard, phone/tablet/split layout
- Web/iOS persistent family-data 정책과 offline mutation/outbox

## Remaining Risks and Completion Boundary

1. generic secure-cache 최대 크기를 넘는 대형 snapshot write는 fail closed하고 online
   content는 유지하지만 실제 Android encrypted serialization 비용은 측정하지 않았다.
2. fixed slot은 가장 최근 Everyone 또는 Me query 하나만 보존한다. query mismatch는
   안전하게 표시하지 않지만 여러 filter의 offline history를 제공하지 않는다.
3. cache local date와 online Chore local date가 다르면 composition은 fail closed하여
   Calendar section error/retry가 나타날 수 있다. device clock으로 임의 보정하지 않는다.
4. authorization loss 자동 계약은 clear를 검증했지만 remote revoke가 app에 도달하는
   지연과 OS process lifecycle은 실제 환경 검증 전까지 완료 근거가 아니다.
5. 따라서 WP04-09 local automated slice만 완료하며 Phase 04, release gate와 장기 기능
   목표는 `PARTIAL/IN_PROGRESS`를 유지한다.

## Rollback

- `today_calendar_v1` adapter/port/provider/controller/UI marker와 repository decorator를
  함께 revert하면 WP04-08의 in-memory-only Calendar stale behavior로 돌아간다.
- Android runtime에서 persistent read-cache flag를 끄면 기존 online repository와 no-op
  snapshot cache가 사용된다.
- 전용 read-cache namespace `deleteAll` 또는 Calendar slot delete는 local family cache만
  제거하고 auth session, notification storage와 server data를 건드리지 않는다.
- DB/API migration이 없어 server rollback과 data backfill은 없다.

## Next Entry Condition

- 다음 기능 우선순위는 `FR-CHORE-001`에 남은 one-time chore edit/delete vertical
  slice다. 반복 회차/시리즈 변경은 이미 있지만 단건의 일반 수정·삭제 command와 UI가
  없어 핵심 CRUD가 비대칭인 현재 가장 큰 local 기능 공백이다.
- 다음 slice는 expected version, idempotency, active-adult role, completed/history 보존,
  Today/upcoming/overdue/completed cache invalidation과 optimistic conflict recovery 계약을
  migration/API/client보다 먼저 고정한다. approval 상태는 별도 정책 범위로 남긴다.
- persistent cache 범위를 Web/iOS, background authority 또는 offline mutation으로 넓히지
  않는다. 해당 범위는 별도 decision/contract와 마지막 integration gate가 필요하다.
- 실제 계정·remote·두 기기·실기기 검증은 사용자 지시에 따라 기능 개발이 충분히
  진행된 뒤 마지막 gate에 계속 유지한다.
