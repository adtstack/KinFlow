# Phase 07 WP07-02A Personal Data Export Evidence

- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- 범위: settings preflight/request/status/cancel, 동일 사용자 최근 OAuth, leased personal snapshot, private JSON/TXT artifact, hash-only 일회성 download grant, expiry/revoke/purge와 platform download handoff
- 제외: Owner full-household export/deletion, 최종 법률 보관 정책, hosted migration/Storage/function/scheduler, Supabase/Google 실계정, 실제 browser download residue, multi-device와 physical-device forensic

## Acceptance Result

| 계약 | 결과 |
|---|---|
| 인증 사용자가 앱에서 개인 데이터 export를 요청하고 상태를 확인할 수 있음 | PASS — `/settings/data-export`가 preflight, latest/exact status와 idempotent request를 사용하고 settings에서 진입함 |
| 민감한 생성·다운로드·회수에 동일 사용자의 최근 재인증이 필요함 | PASS — request/download/revoke는 access bearer와 별도의 같은 사용자 OAuth AMR proof를 요구하고 600초 초과·다른 사용자·누락을 DB 호출 전에 거부함 |
| export 범위가 개인 데이터로 정확히 제한됨 | PASS — profile, active memberships, 본인이 작성한 chore/calendar, 본인의 action/participation, notification metadata, provider-ID-free billing/privacy summary만 포함함 |
| 다른 가족의 identity와 전체 shared household archive가 유출되지 않음 | PASS — 다른 member profile/email/avatar, 다른 사용자가 작성한 unrelated content, provider/customer/transaction/receipt/device identifier를 exact snapshot과 테스트에서 제외함 |
| machine-readable와 human-readable 파일을 모두 제공함 | PASS — pinned schema의 pretty UTF-8 JSON과 deterministic UTF-8 plain text를 생성하고 각 파일을 10 MiB 이하로 제한함 |
| 재시도·동시 요청이 중복 export를 만들지 않음 | PASS — user advisory transaction lock, privacy request partial uniqueness와 operation+request-fingerprint idempotency가 replay만 허용하고 collision/다른 pending privacy request를 거부함 |
| 처리 시작 전 취소하고 완료 artifact를 회수할 수 있음 | PASS — queued/verifying만 expected-version cancel이 가능하고 completed artifact는 expected artifact version revoke로 즉시 unavailable 처리됨 |
| artifact와 link가 영구 공개되지 않음 | PASS — private `privacy-exports` bucket, 기본 24시간 artifact TTL, 기본 5분 grant TTL, expiry/revoke purge queue와 bounded retry/dead-letter를 사용함 |
| download grant를 재사용하거나 DB에서 원문 token을 복원할 수 없음 | PASS — 32-byte token의 SHA-256 hash만 저장하고 GET에서 원자적으로 한 번 consume하며 두 번째·만료·회수 접근은 410으로 거부함 |
| download response가 파일과 metadata를 방어적으로 검증함 | PASS — object key pattern, DB size와 SHA-256을 대조하고 `no-store`, attachment, CSP sandbox, `nosniff`, `no-referrer` headers를 강제함 |
| worker가 경쟁 실행과 crash에서 bounded recovery를 가짐 | PASS — generation 최대 3건/240초 lease, purge 최대 10건/120초 lease, `FOR UPDATE SKIP LOCKED`, 최대 5회와 expired-lease recovery를 검증함 |
| client가 URL이나 export body를 보관하지 않음 | PASS — one-time URL은 Riverpod state·secure storage·read cache에 넣지 않고 launcher port로 즉시 전달하며 production URL은 HTTPS만 허용함 |
| unsupported composition이 안전하게 실패함 | PASS — real auth composition만 `url_launcher` adapter를 사용하고 unavailable composition은 fail-closed launcher로 download를 거부함 |
| UI가 localized/accessibility-safe함 | PASS — EN/KO/EN-XA generated ARB, semantic live status, compact layout와 200% pseudo-locale widget 시나리오가 통과함 |

## Implemented Contract

- 규범 버전은 `2026-08-08-wp07-02a`이며 상세 원문은 `docs/contracts/data-export.yaml.md`다.
- `data-export` Edge function은 최대 8 KiB JSON의 exact `preflight | status | request | cancel | download | revoke` body만 허용하고 응답을 `no-store`로 반환한다.
- request/cancel/revoke command는 동일 operation과 request fingerprint의 replay만 허용한다. 같은 key의 다른 operation/payload는 `IDEMPOTENCY_KEY_REUSED`다.
- request/download/revoke는 bearer session과 별도의 최대 10분 same-user OAuth proof를 요구한다. recent proof는 DB argument, audit 또는 response에 전달하지 않는다.
- personal package의 exact top-level key는 `schemaVersion`, `generatedAt`, `scope`, `profile`, `memberships`, `authoredChores`, `choreActions`, `authoredCalendarEvents`, `calendarParticipation`, `notificationPreferences`, `notificationInbox`, `billingSummary`, `privacyRequests`다.
- worker는 최대 3개 generation job과 10개 purge job을 claim한다. generation/purge lease는 각각 240초/120초이고 최대 5회 bounded exponential retry 뒤 dead-letter로 끝난다.
- JSON/TXT는 각각 최대 10 MiB이며 private bucket에 UUID prefix object로 저장된다. checksum, size와 expiry만 safe projection에 노출되고 object key는 client response에서 제외된다.
- public download function은 정확히 하나의 43자 base64url token만 받고 grant를 원자적으로 consume한 뒤 private object의 key/size/checksum을 재검증하여 stream한다.
- 기본 artifact retention은 86,400초이고 download grant는 300초다. revoke는 outstanding grant를 무효화하고 purge를 즉시 eligible로 만든다.
- lifecycle/runtime audit는 immutable이고 raw bearer/recent-auth/idempotency/download token, hash, object body/key, email, family content와 provider identifier를 금지한다.
- Flutter domain/repository/controller/download port에는 Supabase와 `url_launcher` import가 없다. 두 SDK adapter는 infrastructure/composition 경계에만 존재한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS — ordered 35 migrations including `20260808110000_personal_data_export_lifecycle.sql` and synthetic seed |
| focused WP07-02A pgTAP | PASS — 47 tests covering RLS/least privilege, exact scope/exclusion, idempotency, cancel, generation, grant consume, revoke, expiry/purge, retry and immutable audit |
| full database regression | PASS — 43 files / 2,263 pgTAP tests |
| database lint | PASS — `app_private`, `extensions`, `public`; schema error 0 |
| data export Edge contract | PASS — 17/17 exact body, recent-auth, projection/redaction and HTTPS/local URL rules |
| public download contract | PASS — 4/4 token validation, one-time stream, object verification and security headers |
| generation/purge worker contract | PASS — 5/5 rendering, upload/checksum, cleanup, aggregate response and retry classification |
| repository JavaScript contract regression | PASS — 206/206 |
| focused Flutter feature suites | PASS — initial domain/repository/controller/widget/source slice 30/30 |
| expanded Flutter security/composition suites | PASS — 57/57 including real/unavailable launcher wiring and URL non-retention |
| localization/pseudo widget suites | PASS — 9/9 including 200% EN-XA; new pseudo strings satisfy the 130% expansion contract |
| full Flutter regression | PASS — 690 tests passed; local-connectivity opt-in 1 explicitly skipped |
| Flutter analyzer | PASS — issue 0 on exact Flutter 3.44.7 / Dart 3.12.2 final tree |
| formatter | PASS — 427 Dart files checked; 0 changed |
| offline dependency resolution and localization generation | PASS — `flutter pub get --offline`, exact `flutter gen-l10n`, EN/KO/EN-XA generated files |
| dependency license inventory | PASS — 167 Pub and 15 npm packages; `url_launcher` family accepted by repository license policy |
| public configuration validation | PASS — examples valid and allowlisted; worker secret is rejected from client-visible config |
| repository secret scan | PASS — high-confidence secret 0, including server-only export worker secret classification |
| repository code generation check | PASS — build_runner produced one identical output; generated-code drift 0 across 8 tracked files |
| contract YAML and OpenAPI parse | PASS — data export, OpenAPI, error and env contracts parse; OpenAPI refs 82, paths 27, schemas 60 |
| ARB JSON parse | PASS — EN/KO/EN-XA files valid |
| matrix structure | PASS — 13 CSV matrices; requirements 116×18, test 62×11, risk 30×15, release 23×10 among them |
| whitespace | PASS — `git diff --check` output 0 before this evidence update |

All users, households, memberships, requests, jobs, command IDs, grants, object metadata, timestamps and token-shaped values were synthetic local fixtures. No production credential, real email or family content, Supabase/Google/Store account, hosted project, actual Storage object, browser download or physical device was used.

## Files and Migration

- Server lifecycle:
  - `supabase/migrations/20260808110000_personal_data_export_lifecycle.sql`
  - `supabase/functions/data-export/index.ts`
  - `supabase/functions/data-export-download/index.ts`
  - `supabase/functions/data-export-worker/index.ts`
  - `supabase/functions/_shared/data_export_contract.mjs`
  - `supabase/functions/_shared/data_export_runtime.mjs`
  - `supabase/functions/_shared/data_export_download_contract.mjs`
  - `supabase/functions/_shared/data_export_download_runtime.mjs`
  - `supabase/functions/_shared/data_export_worker_contract.mjs`
  - `supabase/functions/_shared/data_export_worker_runtime.mjs`
- Flutter feature:
  - `apps/kinflow_app/lib/features/settings/domain`
  - `apps/kinflow_app/lib/features/settings/data`
  - `apps/kinflow_app/lib/features/settings/application`
  - `apps/kinflow_app/lib/features/settings/presentation`
  - `apps/kinflow_app/lib/infrastructure/supabase/supabase_data_export_data_source.dart`
  - `apps/kinflow_app/lib/infrastructure/url_launcher/url_launcher_data_export_download_launcher.dart`
  - auth dependency composition, router/guard, settings entry, EN/KO/EN-XA ARB and generated localization files
- Automated tests:
  - `supabase/tests/database/personal_data_export_lifecycle.test.sql`
  - `supabase/tests/data-export-edge-contract.test.mjs`
  - `supabase/tests/data-export-download-contract.test.mjs`
  - `scripts/ci/data-export-worker-contract.test.mjs`
  - `apps/kinflow_app/test/features/settings/data_export_*_test.dart`
  - `apps/kinflow_app/test/infrastructure/supabase_data_export_data_source_test.dart`
  - auth dependency-composition and route compatibility tests
- Contracts/traces:
  - `docs/contracts/data-export.yaml.md`
  - database schema, RLS, OpenAPI, stable error, env and audit contracts
  - Phase 07, implementation/master specifications, requirements/test/platform matrices, workplan and this evidence
- Runtime dependency delta:
  - exact direct `url_launcher 6.3.2` plus lockfile platform implementations
  - native permission/config delta: **none**

## Security, Privacy and Operational Impact

- authenticated clients cannot invoke service commands, workers or private tables directly. Edge derives the user from the verified bearer identity; a request body cannot choose another user.
- recent authentication is a separate same-user OAuth AMR proof bounded to 600 seconds. It is checked before DB mutation and never persisted or reflected.
- transaction advisory locking serializes privacy-request creation per user across request types. A UI preflight race therefore cannot bypass the single-pending-request invariant.
- the export producer uses allowlisted fields, not generic table dumps. Other-member identity, unrelated shared content, notification body, endpoint credential and billing/provider identifiers are excluded by construction.
- raw grant tokens are never stored. A 32-byte token is represented only by its SHA-256 hash and atomically becomes consumed before private object access.
- command response projections hide object keys, checksums, grants, leases and worker detail. Worker response contains aggregate counters only.
- download URL parsing is fail closed: production accepts HTTPS only, while HTTP is limited to `localhost` and `127.0.0.1` for local automation.
- one-time URLs are handed directly to the platform and are absent from Riverpod state, secure storage and encrypted read cache. The app itself never persists export bodies.
- private objects are independently checked against DB key pattern, byte size and SHA-256 before streaming. A mismatched object is not returned.
- revoke immediately invalidates outstanding links and marks the artifact unavailable; purge object deletion is recoverable through leased retry/dead-letter while requests and immutable audit remain.
- `KINFLOW_DATA_EXPORT_WORKER_SECRET` is server-only and forbidden in public config. Runtime request/download pause is service-role-only and expected-version audited.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google/Supabase 재인증, 실제 family account와 여러 사용자 identity/scope 확인은 **NOT USED / NOT RUN**이다.
- hosted Supabase migration, private Storage bucket/object lifecycle, three Edge functions, worker secret/scheduler, retry/dead-letter alert와 operator recovery drill은 **NOT RUN**이다.
- Chrome/Safari/Android/iOS browser 또는 download handler의 실제 파일 저장, URL/history/cache residue와 만료 뒤 재접근은 **NOT RUN**이다.
- multi-device에서 grant 발급과 동시에 revoke/expiry/purge하는 race, offline 전환, process death와 physical-device Downloads UI는 **NOT RUN**이다.
- 큰 실사용 계정의 10 MiB 상한, generation latency/memory, Edge streaming과 Storage checksum semantics는 **NOT RUN**이다.
- Owner full-household export/deletion은 WP07-02B, public privacy request/deletion site는 WP07-07 범위다.
- 최종 legal retention/SLA/copy, production bucket lifecycle와 operator access policy는 승인 전 추정하지 않는다.

## Remaining Risks and Completion Boundary

1. local Storage adapter contract는 upload/download/delete와 checksum sequence를 검증하지만 hosted Supabase Storage의 실제 metadata, timeout, partial upload와 object cleanup 결과를 증명하지 않는다.
2. platform launcher에 URL을 넘긴 뒤의 browser history, download manager, filesystem backup과 공유 UI는 앱 통제 밖이다. 마지막 physical-device forensic Gate가 필요하다.
3. grant는 object read 전에 one-time consume된다. Storage의 일시적 실패 뒤 재사용은 의도적으로 금지되므로 새 grant 발급 UX와 hosted failure telemetry를 실환경에서 확인해야 한다.
4. 10 MiB per-file bound는 안전 상한이지만 큰 장기 사용 계정이 이 범위에 들어오는지 production-shaped synthetic load와 hosted memory/latency evidence가 아직 없다.
5. purge lease/retry는 로컬 경쟁 테스트를 통과했지만 revoke·download·purge가 여러 region/device에서 겹치는 hosted timing은 증명하지 않았다.
6. private bucket과 function 배포, scheduler/secret rotation, dead-letter monitoring 및 법률 보관 정책이 아직 운영 승인되지 않았다.
7. 이번 package는 개인 범위만 제공한다. Owner가 가족 전체 archive를 요청하거나 household deletion 전에 package를 받는 요구는 WP07-02B까지 충족되지 않는다.

WP07-02A의 personal export local vertical slice는 완료했다. 이는 Phase 07 Exit Gate, hosted privacy export 또는 실계정 다운로드 완료가 아니다.

## Rollback

- 신규 요청은 service-only runtime의 `requestsEnabled=false` expected-version update로 즉시 중지한다.
- 새 download grant는 `downloadsEnabled=false`로 중지하고 completed artifact는 revoke하여 outstanding grant를 모두 무효화한다.
- worker scheduler/secret을 비활성화하면 generation/purge를 일시 중단할 수 있다. object 제거가 필요하면 purge queue가 drain될 때까지 worker만 유지한다.
- hosted 적용 전에는 Flutter settings route/composition과 세 Edge functions를 독립적으로 revert할 수 있다.
- client는 `UnavailableDataExportDownloadLauncher`로 fail closed 전환한 뒤 `url_launcher` direct dependency를 제거할 수 있다.
- migration은 forward-only다. hosted 적용 후 destructive down migration 대신 runtime pause와 forward fix를 사용하고 privacy request/checksum/size/immutable audit를 보존한다.
- 이번 local 작업은 외부 account, hosted object 또는 scheduler를 만들지 않았으므로 application-provider rollback 대상이 없다.

## Next Entry Condition

- 기능 우선순위를 유지하면 다음 독립 slice는 WP07-02B Owner household export/deletion이다.
- personal export와 별도로 Owner authorization, last-Owner/ownership race, 전체 household manifest와 member privacy boundary, deletion grace/retention/audit를 먼저 local contract로 고정한다.
- hosted Storage/browser/실계정/실기기 검증은 사용자 순서대로 마지막 Gate에 유지한다.
