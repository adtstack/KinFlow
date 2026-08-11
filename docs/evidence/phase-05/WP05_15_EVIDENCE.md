# Phase 05 WP05-15 Chore Realtime Invalidation Evidence

- Work Package: WP05-15 — Chore/Today content-free Realtime invalidation
- 기준 commit: base `a85f262`; implementation은 2026-08-10 현재 연속 dirty workspace
- 검증일: 2026-08-10
- 환경: macOS arm64, Flutter 3.44.7, Dart 3.12.2, local Supabase
- 결과: **LOCAL AUTOMATED PASS / HOSTED·REAL-ACCOUNT·TWO-DEVICE·PHYSICAL-DEVICE GATES DEFERRED**

## Requirements

| ID | 결과 | Evidence |
|---|---|---|
| WP05-15 / CAP-013 / T-SYNC-02 | PASS FOR LOCAL SLICE / OVERALL PARTIAL | Chore-visible DB change를 content-free household generation으로 게시하고 Today/Chores가 connect·new generation·reconnect·resume 때 authoritative first page를 다시 읽는다. Hosted propagation은 남았다. |
| FR-TODAY-004 | PASS FOR NEW LOCAL SURFACE / OVERALL PARTIAL | transport 단절은 마지막 성공 Chore를 stale로 유지하고 EN/KO/EN-XA 재연결 action을 제공한다. authorization loss는 retained content를 폐기한다. |
| FR-TODAY-005 | PASS FOR NEW LOCAL SURFACE / OVERALL IN PROGRESS | Today primary/overdue는 독립 채널과 source-local failure를 유지하고 하나의 stale banner로 합친다. 다른 source 실패가 Chore content를 숨기지 않는다. |
| NFR-SEC-01 / NFR-PRIV-01 | PASS FOR NEW LOCAL SURFACE | forced-RLS active-member SELECT-only table은 exact 세 필드뿐이고 contentful Chore table은 publication에 추가하지 않는다. strict adapter는 extra/malformed/provider detail을 거부한다. |
| NFR-REL-01 | PASS FOR LOCAL INVALIDATION STATE MACHINE | statement-batched monotonic generation, duplicate/역순 무시, in-flight coalescing, reconnect gap closure, household switch와 deterministic disposal을 자동 검증했다. |
| NFR-A11Y-01 / NFR-I18N-01 | PASS FOR LOCAL AUTOMATION / DEVICE PARTIAL | semantic reconnect button, live stale text와 EN/KO/EN-XA exact coverage 및 200% pseudo-text widget 회귀가 통과했다. 실제 screen reader/기기는 남았다. |

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local database reset | PASS — 66 ordered migrations including `20260810210000_chore_realtime_invalidation.sql`; seed and private Storage bucket restored |
| focused WP05-15 pgTAP | PASS — 29/29 schema, RLS, grants, publication, private writer, producer, batching, replay and visibility assertions |
| full database regression | PASS — 67 files, 3,307 tests, failure 0 |
| database lint | PASS — `app_private,public`, schema error 0 |
| focused Chore sync Flutter contracts | PASS — 25/25 session, repository, strict payload, controller, Today channel and composition assertions |
| full Chore lifecycle widget regression | PASS — 51/51 including disconnected retention, two-source reconnect and 200% surfaces |
| full Flutter regression | PASS — 1,410 tests; existing local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — fatal info/warning enabled, issue 0 |
| Dart formatter | PASS — 727 files checked, drift 0 |
| localization and generated code | PASS — EN/KO/EN-XA generated localization current; build runner wrote 0 outputs; 8 generated files current |
| public configuration and secret scan | PASS — examples valid/allowlisted; high-confidence finding 0 |
| repository Node contracts | PASS — 157/157 |
| CI workflow/action lint | PASS — 6 jobs, 22 pinned action uses, `contents:read`; GitHub Actions workflow lint passed |
| documentation structure | PASS — Chore sync fenced YAML parses; 13 matrices rectangular with declared counts; requirements 127×18, platform 20×12, tests 99×11; 435 Markdown files have balanced fences |
| line coverage | PASS — 30,009/37,436, 80.16% |
| production Web build | PASS — 6,472,907-byte `main.dart.js`; SHA-256 `cabf5ce217168180201c94b33bfab856fffbb10d36d0218e334973af68978c73`; PWA manifest absent, service worker and persistent API cache disabled |
| whitespace | PASS — `git diff --check` output 0 at final handoff |

The Flutter suite's single skip is the pre-existing opt-in local-connectivity test. It is not a skipped WP05-15 assertion. The first actionlint attempt could not resolve GitHub inside the restricted network; rerunning the same pinned downloader with approved network access fetched the official binary and the actual workflow lint passed.

## Contract Evidence

- `public.chore_sync_watermarks` has exactly `household_id`, positive monotonic `generation`, and UTC `changed_at`, with one row per household after the first visible change.
- forced RLS allows authenticated active members of the exact household to select. Anonymous, outsider and removed-member reads are empty; authenticated insert/update/delete and every API-role call to private writers are denied.
- statement-level transition-table triggers cover occurrence insert/update, series update, member update and household update. A multi-row statement advances each affected household at most once.
- an idempotent one-time Chore create replay does not advance generation. Existing Chore mutation signatures, expected-version rules, idempotency keys, event tables and content tables remain unchanged.
- only the watermark is added to `supabase_realtime`; `chore_series`, revisions and occurrences are not published. The invalidation row contains no title, description, assignee/member/actor, series/occurrence, command or correlation data.
- the Supabase adapter subscribes with an exact household filter and exact three-column projection. Extra keys, wrong household, non-positive generation and non-UTC time fail closed to disconnected without surfacing raw provider detail.
- `ChoreSyncSession` owns one subscription per controller, ignores duplicate/older generations, coalesces refreshes, replaces the channel on reconnect/resume, closes the connect gap with a full refetch and invalidates callbacks from old epochs.
- Today composes at most primary plus overdue channels and Chores Hub uses one. Household switch removes old content and channel before exposing the new household; dispose cancels deterministically.
- transport failure retains the last successful page with a stale banner. `unauthenticated` and `notFoundOrForbidden` purge retained content and stop the channel; other typed refresh failures remain source-local.
- nullable composition keeps Realtime disabled without breaking initial, manual, resume or explicit refresh behavior.

## Manual and Deferred Validation

- hosted migration/publication and actual Supabase Realtime propagation latency: **NOT RUN**.
- adult real accounts, member removal while subscribed and active-household authorization timing: **NOT RUN**.
- two-device create/complete/reopen/skip/reassign/reschedule/series-edit/delete/restore races: **NOT RUN**.
- Android physical-device foreground/background/resume, airplane mode, network handoff, process death and OEM behavior: **NOT RUN**.
- actual TalkBack/phone/tablet 200% text and Web browser reconnect matrix: **NOT RUN**.
- delta/cursor merge, durable Realtime inbox, background notification replacement and arbitrary offline write remain outside this slice.

## Files and Impact

- Contract/traceability: `chore-sync.yaml.md`, Phase 05 WP05-15, database/RLS/domain-event contracts, CAP-013, T-SYNC-02 and requirements matrices
- Database: `supabase/migrations/20260810210000_chore_realtime_invalidation.sql`, `supabase/tests/database/chore_realtime_invalidation.test.sql`
- Domain/data/application: Chore sync signal/repository/data-source ports, provider repository, `ChoreSyncSession`, `TodayChoresController` and sync status state
- Composition/infrastructure: nullable provider wiring, `AuthDependencies`, `SupabaseChoreSyncDataSource` and bootstrap override
- Presentation: Today stale/reconnect composition, app-resume reconnect and EN/KO/EN-XA ARB/generated localization
- Public RPC signature, content table shape, app permission, native dependency/manifest, cache slot, analytics event/property and deep-link delta: **none**

## Remaining Risks and Completion Boundary

1. Realtime is a lossy invalidation hint, not the data authority. Correctness depends on every connect/reconnect/resume/new generation causing an RLS-authorized full refetch; local automation proves the state machine, not hosted transport timing.
2. publication membership and RLS behavior passed local Postgres, but hosted project publication drift or token refresh timing can only be judged in the final real-account Gate.
3. Today intentionally uses two independent Chore channels for primary and overdue queries. Tests bound this topology, but hosted connection quotas and OEM network transitions still require operational observation.
4. disconnect retains potentially stale content for usability; authorization failures are therefore classified separately and purge immediately. A hosted membership-removal race remains the highest-priority live security check.

WP05-15 자체는 local deterministic server/client slice로 완료했다. CAP-013 전체와 운영 Realtime 신뢰성의 최종 판정은 사용자 지시에 따라 기능 개발 이후 실계정·두 기기·실기기 Gate에 유지한다.

## Commands

```text
npx --no-install supabase db reset --local
npx --no-install supabase test db supabase/tests/database/chore_realtime_invalidation.test.sql
npx --no-install supabase test db supabase/tests/database
npx --no-install supabase db lint --local --schema app_private,public --level warning --fail-on error
flutter test --no-pub <focused Chore sync/controller/provider/composition files>
flutter test --no-pub test/features/chores/one_time_chore_widget_test.dart
flutter test --no-pub
KINFLOW_FLUTTER_BIN=<exact Flutter 3.44.7> KINFLOW_PUB_OFFLINE=1 scripts/ci/flutter-quality.sh
KINFLOW_FLUTTER_BIN=<exact Flutter 3.44.7> KINFLOW_PUB_OFFLINE=1 scripts/ci/web-build.sh prod
Ruby YAML/Markdown/matrix structure checks
git diff --check
```

## Rollback

- set the nullable Chore sync repository composition to `null` or remove client wiring; initial/manual/resume list reads continue without Realtime.
- remove `public.chore_sync_watermarks` from `supabase_realtime`, then remove producer triggers, private functions, policy/grant and table through a forward migration.
- keep existing Chore series, revisions, occurrences, events, commands and caches untouched. The watermark is derived content-free metadata and can be discarded without domain-data loss.
