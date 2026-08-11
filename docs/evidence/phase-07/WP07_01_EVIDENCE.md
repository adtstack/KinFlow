# Phase 07 WP07-01 Account Deletion Evidence

- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- 범위: 앱 내 preflight/request/status/cancel, 동일 사용자 최근 OAuth, 기본 24시간 취소, last-Owner·active subscription gate, leased identity tombstone/Auth soft-delete worker, settings UI와 logout/local purge handoff
- 제외: 공개 웹 요청, household deletion/export, 법률 문구·보관 승인, hosted migration/function/scheduler, Supabase/Google/Store 실계정, multi-device와 physical-device forensic

## Acceptance Result

| 계약 | 결과 |
|---|---|
| 앱 안에서 삭제를 시작하고 상태와 취소 가능 시간을 확인할 수 있음 | PASS — 인증 사용자는 household가 없어도 `/settings/account-deletion`에 접근하며 preflight, latest/exact status, request와 optimistic-version cancel을 사용함 |
| 삭제 요청에 동일 사용자의 최근 재인증이 필요함 | PASS — request만 별도 `X-KinFlow-Recent-Auth` OAuth AMR proof를 요구하고 600초 초과·다른 사용자·누락을 DB 호출 전에 거부함 |
| 재시도와 동시 요청이 중복 legal request를 만들지 않음 | PASS — 사용자 advisory transaction lock, partial unique index와 operation+request-hash idempotency record; 같은 command replay는 이전 결과를 반환하고 collision은 거부함 |
| 사용자가 취소할 시간을 갖고 processing 이후 취소할 수 없음 | PASS — 기본 86,400초, 허용 범위 1시간~7일, queued/verifying만 cancellable, expected version과 상태를 transaction에서 재검증함 |
| 마지막 Owner가 shared household를 고아로 만들 수 없음 | PASS — preflight/request/tombstone 직전의 세 단계 server check가 active Owner membership 하나라도 있으면 거부하고 Flutter는 member-management resolution을 제공함 |
| active Store subscription이 자동 취소된다고 오인하지 않음 | PASS — active subscription을 aggregate boolean으로 계산하고 Store에서 별도 관리해야 함을 설명하며 acknowledgment 없이는 UI와 DB 모두 요청을 차단함 |
| shared family data를 account deletion과 함께 삭제하지 않음 | PASS — household, chore, calendar, other-member data와 billing/audit history를 보존하고 삭제 사용자의 profile/member identity와 personal state만 tombstone함 |
| endpoint/token/local state가 삭제 사용자에게 남지 않음 | PASS — endpoint ciphertext/fingerprint/proof를 비가역 tombstone material로 교체하고 personal inbox/preference/selection을 제거; 요청 접수 후 기존 logout composition이 endpoint revoke, RevenueCat/Google/secure auth/cache/pending invite purge를 수행함 |
| old JWT와 삭제 identity가 authorization을 되찾지 못함 | PASS — active-profile-aware profile/member/billing-owner helpers와 membership creation trigger가 tombstoned identity를 fail closed로 처리함 |
| worker가 중복 처리 없이 tombstone 뒤 Auth deletion을 수행함 | PASS — due job을 `FOR UPDATE SKIP LOCKED`로 lease하고 lease/request/Owner를 재검증한 뒤 DB tombstone → Auth Admin soft-delete → completion 순서를 강제함 |
| 일시적 Auth 장애와 worker crash가 bounded recovery를 가짐 | PASS — 120초 lease, 최대 5회, 60초부터 최대 1시간 exponential retry, expired-lease recovery와 terminal dead-letter를 검증함 |
| API와 audit에 identity/provider/content가 노출되지 않음 | PASS — exact projections, aggregate worker counters, allowlisted ≤1 KiB audit metadata와 malformed provider-field redaction을 검증함 |
| 앱 계약이 provider-neutral하고 localized/accessibility-safe함 | PASS — domain/repository/controller는 SDK import가 없고 Supabase adapter는 infrastructure에만 있음; EN/KO/EN-XA ARB와 semantic live status 및 compact 200% pseudo widget이 통과함 |

## Implemented Contract

- 규범 버전은 `2026-08-08-wp07-01`이며 상세 원문은 `docs/contracts/account-deletion.yaml.md`다.
- `account-deletion` Edge function은 최대 8 KiB JSON의 exact `preflight | status | request | cancel` shape만 허용하고 모든 응답을 `no-store`로 반환한다.
- request/cancel idempotency key는 16~200자다. 같은 user/key/operation/payload replay만 허용하고 다른 operation 또는 acknowledgment 조합은 `IDEMPOTENCY_KEY_REUSED`다.
- request는 access bearer와 별도로 같은 user의 최대 10분 OAuth AMR proof가 필요하다. recent proof는 DB argument, audit 또는 response에 전달하지 않는다.
- account deletion과 household deletion은 분리된다. 삭제 사용자의 shared membership identity는 `Deleted member` tombstone이 되지만 household/chore/calendar row는 보존된다.
- active subscription은 자동 취소하지 않고 billing assignment/history도 삭제하지 않는다. 사용자가 Store에서 별도 관리해야 함을 확인한 경우만 request를 허용한다.
- private job은 최대 10건을 claim하고 120초 lease를 사용한다. 처리 순서는 personal DB tombstone, Supabase Auth Admin soft-delete, completed transition이다.
- transient Auth unavailable은 bounded retry, permanent rejection·precondition failure·attempt exhaustion은 dead-letter와 stable failure code로 끝난다.
- request/job/runtime audit는 immutable이며 raw token, recent-auth proof, idempotency key, email, provider/customer/transaction/receipt와 family content를 저장하지 않는다.
- 요청 접수 즉시 client logout handoff를 예약하여 remote endpoint revoke와 RevenueCat/Google identity, secure auth, encrypted read cache, pending invite를 정리한다.

## Automated Validation

| 검증 | 결과 |
|---|---|
| clean local Supabase reset | PASS — ordered 34 migrations including `20260808100000_account_deletion_lifecycle.sql` and synthetic seed |
| focused WP07-01 pgTAP | PASS — 50 tests including RLS/least privilege, idempotency, last Owner, subscription gate, cancel, tombstone, audit, retry/completion and competing worker claim |
| account-deletion plus billing compatibility pgTAP | PASS — 98 tests; missing-profile membership compatibility regression fixed while tombstoned-profile denial remains |
| full database regression | PASS — 42 files / 2,216 pgTAP tests |
| database lint | PASS — `app_private`, `extensions`, `public`; schema error 0 |
| account deletion Edge and worker contract | PASS — 22/22, rerun after documentation |
| repository JavaScript contract regression | PASS — 122/122 |
| focused Flutter settings/auth/router/composition suites | PASS — domain invariants, exact parser/error mapping, retry ID, recent auth, status/cancel, logout handoff, owner/subscription gates and no-household routes |
| account deletion widget scenarios | PASS — subscription acknowledgment+logout, cancellation, Owner resolution and compact 200% EN-XA |
| full Flutter regression | PASS — 659 tests; local-connectivity opt-in 1 skip; all remaining tests passed |
| Flutter analyzer | PASS — issue 0 on exact Flutter 3.44.7 / Dart 3.12.2 final tree |
| formatter | PASS — 403 Dart files checked; 0 changed |
| localization generation | PASS — exact `flutter gen-l10n`; EN/KO/EN-XA account-deletion keys generated |
| public configuration validation | PASS — examples valid and allowlisted; deletion worker secret is not client config |
| repository secret scan | PASS — high-confidence secret 0 |
| repository code generation check | PASS — build_runner wrote 0 outputs; generated-code drift 0 across 8 files |
| contract YAML parse | PASS — all Markdown-wrapped YAML contracts including account deletion, OpenAPI, error catalog and domain events |
| matrix structure | PASS — 13 CSV matrices; requirements 116×18, test 62×11, risk 30×15, release 23×10 among them |
| whitespace | PASS — `git diff --check` output 0 after final documentation |

All users, households, memberships, requests, command IDs, leases, provider responses, timestamps and token-shaped values were synthetic local fixtures. No production credential, real email or family content, Supabase/Google/RevenueCat/Store account, hosted project, sandbox purchase, push provider or physical device was used.

## Files and Migration

- Server lifecycle:
  - `supabase/migrations/20260808100000_account_deletion_lifecycle.sql`
  - `supabase/functions/account-deletion/index.ts`
  - `supabase/functions/account-deletion-worker/index.ts`
  - `supabase/functions/_shared/account_deletion_contract.mjs`
  - `supabase/functions/_shared/account_deletion_runtime.mjs`
  - `supabase/functions/_shared/account_deletion_worker_contract.mjs`
  - `supabase/functions/_shared/account_deletion_worker_runtime.mjs`
- Flutter feature:
  - `apps/kinflow_app/lib/features/settings/domain`
  - `apps/kinflow_app/lib/features/settings/data`
  - `apps/kinflow_app/lib/features/settings/application`
  - `apps/kinflow_app/lib/features/settings/presentation`
  - `apps/kinflow_app/lib/infrastructure/supabase/supabase_account_deletion_data_source.dart`
  - auth dependency composition, app router/guard, Today settings entry, EN/KO/EN-XA ARB and generated localization files
- Automated tests:
  - `supabase/tests/database/account_deletion_lifecycle.test.sql`
  - `supabase/tests/account-deletion-edge-contract.test.mjs`
  - `scripts/ci/account-deletion-worker-contract.test.mjs`
  - `apps/kinflow_app/test/features/settings`
  - `apps/kinflow_app/test/infrastructure/supabase_account_deletion_data_source_test.dart`
  - auth route-guard/dependency-composition compatibility tests
- Contracts/traces:
  - `docs/contracts/account-deletion.yaml.md`
  - database schema, RLS, OpenAPI, stable error and private lifecycle-audit contracts
  - Phase 07, implementation specification, requirements/test/risk/release matrices, workplan and this evidence
- Runtime package dependency, lockfile, native permission and client public-config delta: **none in WP07-01**.

## Security, Privacy and Operational Impact

- authenticated clients cannot call service RPCs or private tables directly. Edge derives the user ID from verified bearer identity; request bodies cannot choose another user.
- recent authentication is a separate same-user proof. It is bounded to OAuth AMR at 600 seconds and never reaches PostgreSQL or audit storage.
- preflight exposes only Owner count, subscription boolean, pending request ID/status/version, runtime state/window and evaluation time. It exposes no household, member, billing or provider identifier.
- request and cancel are serialized per user. UI preflight is advisory; DB constraints and transaction rechecks own concurrency correctness.
- last Owner is checked before acceptance and again immediately before irreversible identity work. A membership/role race therefore fails closed.
- encrypted endpoint material is not merely marked revoked: ciphertext, fingerprint and proof hash are replaced with deterministic non-secret tombstone material.
- deleted profile-aware RLS prevents old JWT use of profile, household membership and billing-owner authorization before Auth token expiry.
- worker responses contain only aggregate counters. Auth/provider response bodies and DB diagnostic detail are never reflected to clients.
- worker/runtime secrets remain server-only. Runtime pause stops new requests without deleting queued legal requests or immutable audit.

## Manual and Deferred Validation

- 사용자 지시에 따라 실제 Google 재인증, Supabase Auth soft-delete, old/new JWT, 두 계정·다중 기기 session expiration은 **NOT USED / NOT RUN**이다.
- RevenueCat/Google Play active subscription, Store 관리 화면과 삭제 뒤 결제 상태는 **NOT USED / NOT RUN**이다. 이번 계약은 자동 Store 취소를 명시적으로 금지하고 acknowledgment만 강제한다.
- FCM endpoint의 실제 provider token/ciphertext forensic, Android Keystore local cache forensic, OEM process death와 physical device는 **NOT RUN**이다.
- hosted Supabase migration/functions, worker secret/scheduler, queue latency, retry/dead-letter alert와 operator recovery drill은 **NOT RUN**이다.
- 공개 웹 deletion request site, privacy/terms/support URL, 법률 승인된 보관 예외·SLA 문구는 WP07-07 및 release Gate에 남는다.
- household deletion과 export/download/expiry는 WP07-02 범위이며 이번 account deletion에서 실행하지 않는다.

## Remaining Risks and Completion Boundary

1. local worker contract는 Supabase Auth Admin soft-delete URL·status 분류·호출 순서를 검증하지만 hosted Auth의 실제 세션 만료와 식별자 보존 결과를 증명하지 않는다.
2. server tombstone과 client logout participant는 자동 검증됐지만 실기기 Keystore, provider SDK와 OS backup에 잔존 데이터가 없는지는 마지막 forensic Gate가 필요하다.
3. active subscription 안내와 acknowledgment는 구현됐으나 실제 Store subscription이 유지되고 사용자가 관리 화면에서 취소할 수 있는지 sandbox/실계정 증거가 없다.
4. 여러 household의 Owner인 사용자는 server가 정확한 count로 계속 차단한다. 현재 resolution action은 active household member management로 이동하므로 multi-household 전환 UX는 후속 settings 개선 여지가 있다.
5. privacy request와 immutable audit의 최종 retention/legal hold 정책이 승인되지 않았다. 승인 전 hosted purge 또는 retention job을 추정해 추가하면 안 된다.
6. public web 요청 경로가 아직 없어 D-040, FR-AUTH-008, FR-SET-004, NFR-DEL-01과 Release `REL-009`는 계속 `PARTIAL`이다.

WP07-01의 앱 내 local vertical slice는 완료했다. 이는 Phase 07 Exit Gate, Store deletion compliance 또는 실계정 삭제 완료가 아니다.

## Rollback

- 신규 요청은 service-only `configure_account_deletion_runtime(false, …)`로 즉시 중지하고 immutable runtime event를 남긴다.
- worker scheduler를 중지하거나 dedicated secret을 회전하면 queued request와 audit를 잃지 않고 processing을 일시 중단할 수 있다.
- hosted 적용 전에는 Flutter settings route/composition과 두 Edge functions를 독립적으로 revert할 수 있다.
- migration은 forward-only다. hosted 적용 후 destructive down migration 대신 pause와 forward fix를 사용한다.
- tombstone 또는 Auth soft-delete가 시작된 identity는 rollback으로 복원하지 않는다. code rollback도 privacy request/job/audit를 삭제하지 않는다.
- 이번 local 작업은 외부 account/provider/product를 만들거나 삭제하지 않았으므로 application-provider rollback 대상이 없다.

## Next Entry Condition

- 기능 우선순위를 유지하면 다음 독립 slice는 WP07-02 household deletion/export다. account deletion과 별도 Owner authorization, export manifest, short-lived download, retention/audit를 먼저 local contract로 고정한다.
- 공개 웹 deletion site와 실계정 검증은 사용자의 순서대로 마지막 Gate에 유지한다.
