# Phase 07 WP07-02B Owner Household Export and Deletion Evidence

- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- 범위: current Owner preflight, shared-household JSON/TXT export, private one-time download, exact-name/impact-confirmed background household deletion, cooling-off cancellation, retention hold, access revocation, redaction, billing unlink와 Flutter settings/status UI
- 제외: hosted migration/Storage/functions/scheduler, 실제 Google/Supabase/Store account, browser download residue, multi-device·physical-device forensic, 최종 법률 보관/구성원 통지 정책과 public privacy site

## Acceptance Result

| 계약 | 결과 |
|---|---|
| household privacy 작업은 current Owner에게만 허용됨 | PASS — preflight와 모든 command가 active Owner membership과 `households.owner_member_id`를 서버에서 재검증하며 non-Owner·cross-household 접근은 fail closed함 |
| 전체 shared-household archive 범위가 명시적으로 제한됨 | PASS — household/member roster, chores, calendar, aggregate notification, provider-ID-free billing/privacy summary만 exact payload에 포함함 |
| member 개인 identity와 provider credential이 archive에서 제외됨 | PASS — email/Auth user/provider identity/profile, personal inbox/read state, endpoint token/ciphertext/fingerprint, billing customer/transaction/receipt/product ID와 다른 household를 제외함 |
| JSON과 human-readable text를 private artifact로 생성함 | PASS — pinned schema의 deterministic UTF-8 JSON/TXT를 생성하고 파일별 20 MiB 상한, private bucket prefix, size/checksum metadata를 검증함 |
| export 생성·다운로드·회수에 동일 사용자 recent OAuth가 필요함 | PASS — access bearer와 별도 OAuth AMR proof를 최대 600초로 검증하며 누락·stale·다른 사용자는 RPC 전에 거부하고 proof를 DB나 응답에 전달하지 않음 |
| download link가 만료되고 한 번만 사용됨 | PASS — 원문 32-byte token은 저장하지 않고 SHA-256 hash만 보관하며 5분 grant를 object read 전에 원자 consume함 |
| artifact revoke·expiry·purge가 bounded recovery를 가짐 | PASS — revoke가 outstanding grant를 무효화하고 purge queue는 lease/retry/dead-letter와 object deletion 결과를 분리하여 기록함 |
| deletion은 exact current name과 모든 관련 영향을 확인함 | PASS — household optimistic version, exact name, member access loss, shared-data redaction과 active subscription non-cancellation acknowledgment를 transaction에서 다시 확인함 |
| queued deletion을 cooling-off 동안 취소할 수 있음 | PASS — 기본 24시간 예약과 queued/verifying expected-version cancellation을 제공하며 processing 이후에는 거부함 |
| retention hold가 민감한 내부 사유를 노출하지 않음 | PASS — service-role-only hold는 claim 전에 처리를 정지하고 public status에는 blocked boolean과 review timestamp만 노출함 |
| worker가 stale Owner와 경쟁 실행에 안전함 | PASS — claim 직전 Owner를 다시 확인하고 advisory/row locks, `FOR UPDATE SKIP LOCKED`, bounded lease와 terminal/retry 분류를 사용함 |
| 삭제 완료 즉시 기존 household 접근이 차단됨 | PASS — household deleted marker, 모든 active membership 종료와 active-household selector 제거가 한 transaction에서 수행되어 old JWT RLS도 fail closed함 |
| shared identity/content와 endpoint material이 redaction됨 | PASS — household/member 이름·avatar, chore/calendar content와 creator, invites, notification state와 endpoint cryptographic material을 tombstone/revoke함 |
| 구성원 account와 Store subscription은 잘못 삭제되지 않음 | PASS — 다른 Auth account/profile/household membership과 provider billing history는 보존하고 household entitlement/assignment만 unlink/end하며 Store subscription은 자동 취소하지 않음 |
| client가 one-time URL이나 export body를 보관하지 않음 | PASS — URL은 기존 launcher port에 즉시 전달되고 controller state, local cache와 secure storage에 남지 않음 |
| 설정 UI가 Owner hint와 server authority를 함께 사용함 | PASS — active household preflight가 성공한 Owner에게만 row를 표시하고 direct route와 서버 실패는 권한 오류로 안전하게 처리함 |
| UI가 localized/accessibility-safe함 | PASS — EN/KO/EN-XA 생성 리소스, 130% pseudo expansion, semantic status와 compact 200% widget 시나리오가 통과함 |

## Implemented Contract

- 규범 버전은 `2026-08-08-wp07-02b`이며 상세 원문은 `docs/contracts/household-privacy.yaml.md`다.
- `household-privacy` Edge function은 최대 12 KiB exact JSON의 `preflight | status | requestExport | cancelExport | downloadExport | revokeExport | requestDeletion | cancelDeletion`만 허용한다.
- export/deletion 생성과 cancel/revoke mutation은 UUID idempotency key와 request/household/artifact expected version을 사용한다. 같은 key의 다른 operation 또는 payload는 replay가 아니라 collision이다.
- pending privacy request는 사용자 단위와 household 단위로 export/deletion 사이에서도 하나만 허용한다.
- worker는 한 번에 export 최대 2건, purge 10건, deletion 5건을 claim한다. lease는 각각 300초, 120초, 180초이고 최대 5회 bounded retry 뒤 dead-letter로 끝난다.
- JSON/TXT는 각각 최대 20 MiB이며 private `privacy-exports/household-exports/{artifactPrefix}` 아래 저장된다. object key와 checksum은 public command/status projection에 노출하지 않는다.
- public download function은 정확히 하나의 43자 base64url token만 받고 grant를 consume한 뒤 key pattern, byte size와 SHA-256을 검증하여 `no-store` attachment로 반환한다.
- deletion completion은 access revocation, selector removal, redaction, invite/notification cleanup과 billing unlink를 한 server transaction에서 수행한다. 이미 완료된 deletion은 code rollback으로 복원하지 않는다.
- Flutter domain/repository/controller에는 Supabase import가 없고 infrastructure adapter와 bootstrap composition만 provider SDK에 의존한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS — ordered 37 migrations including `20260808120000_household_export_request_type.sql` and `20260808120100_household_privacy_lifecycle.sql`, synthetic seed only |
| focused WP07-02B pgTAP | PASS — 48 tests covering Owner/Admin/Member authorization, scope/exclusion, idempotency, version/name race, grants, purge, cooling-off, retention, worker claims, RLS revocation, redaction, billing unlink and immutable audit |
| full database regression | PASS — 44 files / 2,311 pgTAP tests |
| database lint | PASS — `app_private`, `extensions`, `public`; warning/error 0 |
| household privacy Edge contract | PASS — 24/24 including exact 12 KiB boundary, recent-auth, optimistic versions, error mapping and response redaction |
| one-time household download contract | PASS — 4/4 token consume, object verification, 20 MiB bound and security headers |
| generation/purge/deletion worker contract | PASS — 7/7 archive rendering, upload/checksum, purge isolation, Owner drift, retry and aggregate response |
| repository JavaScript contract regression | PASS — 241/241 |
| focused Flutter WP07-02B suites | PASS — 30/30 domain, repository, Supabase DTO, controller, feature widget and Owner settings visibility tests |
| auth composition and server-secret classification | PASS — production/unavailable repository wiring and every client-forbidden server key test pass |
| full Flutter regression | PASS — 720 tests passed; local-connectivity opt-in 1 explicitly skipped |
| Flutter analyzer | PASS — issue 0 on exact Flutter 3.44.7 / Dart 3.12.2 tree |
| Dart formatter | PASS — 447 files checked; 0 changed |
| localization generation and pseudo pressure | PASS — EN/KO/EN-XA generated; 555 source messages have exact coverage and EN-XA is at least 130% of English |
| public configuration validation | PASS — examples valid and allowlisted; household worker secret is rejected from client-visible config |
| repository secret scan | PASS — high-confidence secret 0, including `KINFLOW_HOUSEHOLD_PRIVACY_WORKER_SECRET` classification |
| repository code generation check | PASS — build_runner wrote 0 outputs; drift 0 across 8 tracked files |
| contract YAML and OpenAPI | PASS — 18 YAML contracts parse; OpenAPI paths 30, schemas 72, unique refs 95, dangling refs 0 |
| ARB JSON | PASS — EN/KO/EN-XA parse |
| matrix structure | PASS — 13 CSV matrices; requirements 116×18, test 62×11 and all other rows have exact column widths |
| whitespace | PASS — `git diff --check` output 0 after the evidence update |

모든 user, household, membership, privacy request, job, artifact, grant, object metadata, timestamp와 token-shaped value는 synthetic local fixture였다. production credential, 실제 email/family content, Supabase/Google/Store account, hosted object/function 또는 physical device를 사용하지 않았다.

## Files and Migrations

- Server lifecycle:
  - `supabase/migrations/20260808120000_household_export_request_type.sql`
  - `supabase/migrations/20260808120100_household_privacy_lifecycle.sql`
  - `supabase/functions/household-privacy/index.ts`
  - `supabase/functions/household-export-download/index.ts`
  - `supabase/functions/household-privacy-worker/index.ts`
  - `supabase/functions/_shared/household_privacy_contract.mjs`
  - `supabase/functions/_shared/household_privacy_runtime.mjs`
  - `supabase/functions/_shared/household_export_download_contract.mjs`
  - `supabase/functions/_shared/household_export_download_runtime.mjs`
  - `supabase/functions/_shared/household_privacy_worker_contract.mjs`
  - `supabase/functions/_shared/household_privacy_worker_runtime.mjs`
- Flutter feature:
  - `apps/kinflow_app/lib/features/settings/domain`
  - `apps/kinflow_app/lib/features/settings/data`
  - `apps/kinflow_app/lib/features/settings/application`
  - `apps/kinflow_app/lib/features/settings/presentation`
  - `apps/kinflow_app/lib/infrastructure/supabase/supabase_household_privacy_data_source.dart`
  - auth dependency composition, bootstrap, router, settings entry and EN/KO/EN-XA resources
- Automated tests:
  - `supabase/tests/database/household_privacy_lifecycle.test.sql`
  - `supabase/tests/household-privacy-edge-contract.test.mjs`
  - `supabase/tests/household-export-download-contract.test.mjs`
  - `scripts/ci/household-privacy-worker-contract.test.mjs`
  - `apps/kinflow_app/test/features/settings/household_privacy_*_test.dart`
  - `apps/kinflow_app/test/features/settings/provider_household_privacy_repository_test.dart`
  - `apps/kinflow_app/test/infrastructure/supabase_household_privacy_data_source_test.dart`
  - auth composition, localization and secret-scanner regression tests
- Contracts/traces:
  - `docs/contracts/household-privacy.yaml.md`
  - database schema, RLS, OpenAPI, error, environment and audit contracts
  - Phase 07, requirements/test matrices, workplan and this evidence
- Runtime dependency delta: **none** — the feature reuses the existing authenticated Supabase client and `DataExportDownloadLauncher` port.

## Security, Privacy and Operational Impact

- authenticated clients cannot invoke service worker/configuration functions or private tables. Edge derives identity from the verified bearer and ignores all caller-supplied role/user claims.
- Owner status is a server fact, not a settings-row authorization decision. Preflight and mutations verify both the active membership role and current Owner pointer.
- recent OAuth is a separate same-user proof and is never persisted, reflected, logged or forwarded as an RPC argument.
- archive creation uses an allowlisted JSON shape rather than generic table dumps. Removed-member historical references remain opaque while removed identity is excluded.
- raw download token, object key, checksum, artifact body and worker lease never enter the client status envelope or immutable audit metadata.
- one-time grant consumption precedes private object access. A transient read failure intentionally requires a new grant instead of replaying the previous capability.
- deletion redaction is transactionally coupled to access revocation and billing unlink. Partial client state cannot restore access because PostgreSQL remains authoritative.
- active Store subscriptions are explicitly outside household deletion authority. The UI and server both require the non-cancellation acknowledgment when an active assignment exists.
- `KINFLOW_HOUSEHOLD_PRIVACY_WORKER_SECRET` is server-only, forbidden in public configuration and covered by the repository secret scanner.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google/Supabase recent-auth, 실제 Owner/Admin/Member identity와 실제 family content 확인은 **NOT USED / NOT RUN**이다.
- hosted migration, private Storage bucket/object lifecycle, three Edge functions, worker secret/scheduler, retry/dead-letter alert와 operator recovery drill은 **NOT RUN**이다.
- Chrome/Safari/Android/iOS download handler의 실제 파일 저장, URL/history/cache residue, expiry/revoke 뒤 재접근은 **NOT RUN**이다.
- 실제 Store subscription이 있는 household 삭제와 provider dashboard의 subscription 지속 여부는 **NOT RUN**이다.
- multi-device에서 ownership transfer, grant 발급/revoke/purge와 deletion claim이 겹치는 hosted race 및 process death는 **NOT RUN**이다.
- 큰 production-shaped household의 20 MiB 상한, generation latency/memory, Edge streaming과 hosted Storage checksum semantics는 **NOT RUN**이다.
- 구성원 사전 통지·동의 문구, 최종 legal retention/hold taxonomy/operator access, production bucket lifecycle은 승인 전 추정하지 않았다.
- public privacy/deletion site는 WP07-07 범위다.

## Remaining Risks and Completion Boundary

1. local Storage adapter contract는 object sequence와 checksum을 검증하지만 hosted Supabase Storage의 timeout, partial upload, metadata와 cleanup 결과를 증명하지 않는다.
2. 20 MiB 파일별 상한은 안전 경계이나 장기 사용 household가 이 범위에 들어오는지는 production-shaped load와 hosted memory/latency evidence가 필요하다.
3. deletion은 복구 불가능하므로 구성원 notification/consent, legal retention, support escalation과 operator hold 정책이 product/legal 승인을 받아야 한다.
4. platform launcher 이후의 browser history, filesystem backup, 공유 UI와 download manager는 앱 통제 밖이며 마지막 physical-device forensic Gate가 필요하다.
5. row locks와 lease recovery는 로컬 경쟁 테스트를 통과했지만 multi-region hosted timing과 scheduler overlap은 아직 증명하지 않았다.
6. Store subscription은 의도적으로 유지된다. 실제 provider 환경에서 billing unlink와 subscription 지속을 함께 확인해야 한다.
7. 이 package는 local vertical slice 완료이며 Phase 07 Exit Gate, hosted privacy lifecycle 또는 출시 완료가 아니다.

## Rollback

- service-only runtime flags로 새 export, deletion과 download grant 발급을 독립 중지한다.
- worker scheduler/secret을 비활성화하면 generation/deletion/purge claim을 중단하되 queued request와 immutable audit는 보존한다.
- active artifact는 revoke하고 purge queue를 drain한다. deletion은 processing 전 cancel 또는 retention hold로 정지할 수 있다.
- hosted rollout 전 Flutter route/composition과 세 Edge functions를 독립 제거할 수 있다.
- migration은 forward-only다. 이미 완료된 access revocation/redaction/billing unlink를 destructive down migration이나 code rollback으로 복원하지 않는다.
- 이번 local 작업은 외부 account, hosted artifact 또는 scheduler를 만들지 않았으므로 application-provider rollback 대상이 없다.

## Next Entry Condition

- WP07-02B의 Owner authorization, archive privacy boundary, one-time download와 deletion cooling-off/access-revocation/redaction/billing-unlink는 local automation으로 고정됐다.
- 기능 우선순위를 유지하면 다음 독립 slice는 WP07-03 security hardening이다.
- hosted/real-account/browser/Store/multi-device/physical-device 검증은 사용자 순서대로 마지막 Gate에 유지한다.
