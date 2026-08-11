# Phase 06 — 구독과 Household Entitlement

## 목표

App Store/Google Play 구매·복원·갱신·만료·환불을 RevenueCat과 서버가 처리하고, 최종 Plus 권한을 선택된 household에 일관되게 적용한다.

## Entry

가격/limits/restore policy 승인, Store/RevenueCat sandbox 준비.

## Work Packages

### WP06-01 Billing domain/schema

- customer/transaction/event/household entitlement
- state model와 audit
- server feature limit
- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- 구현: provider/environment별 customer와 SHA-256 transaction reference, encrypted receipt boundary, 하나의 active customer↔household assignment, authoritative entitlement와 immutable transition/policy audit
- 순서/복구: verified normalized event의 exact replay 멱등성, payload 충돌 거부, stale/equal-time quarantine, 취소·grace·billing issue·expiry·refund/revoke·restore materialization
- 권한: billing mutation과 policy/limit command는 service-only이고 active household member는 provider/receipt/transaction 식별자 없는 entitlement projection만 읽는다.
- Flutter: provider-independent entitlement domain/repository와 strict Supabase RPC mapper까지 구현했으며 SDK·paywall·화면 composition은 후속 WP다.
- 정책 Gate: D-027 가격·수치 한도가 OPEN이므로 ingestion은 기본 disabled, limits는 unfinalized/fail-closed다. 실제 Store/RevenueCat 계정·sandbox·기기는 마지막 Gate다.
- Evidence: `docs/evidence/phase-06/WP06_01_EVIDENCE.md`

### WP06-02 Product catalog/paywall

- store local price
- monthly/annual/trial copy
- household benefit
- terms/privacy/restore
- accessibility/localization
- 상태: **LOCAL IMPLEMENTED — WP06-02A (2026-08-08)**
- 상태 화면: active household 이름, 서버가 확인한 plan/lifecycle/source/billing-owner 관계, 갱신 또는 현재 기간 종료일과 검증일을 모든 active member에게 표시한다.
- paywall: Store catalog의 exact localized price와 period만 사용하며 provider package/product/customer/transaction ID와 승인 전 D-027 수치를 UI에 표시하지 않는다. benefit은 member/active recurring series/data preservation 범주만 설명한다.
- 권한/확인: authoritative profile household가 billing context와 일치하는 active Owner/Admin만 purchase/restore를 실행할 수 있고, household 이름·Store 가격/기간·자동 갱신·server confirmation 경계를 확인한 뒤 기존 billing controller를 호출한다.
- 상태 복구: assignment 준비/충돌, purchase/restore, Store pending, server confirmation pending, restore empty/conflict, bounded failure를 각각 렌더링한다. pending에서는 중복 CTA를 숨기고 server refresh만 제공하며 conflict는 Store 호출 전에 중지하고 aggregate review/support만 노출한다.
- 관리/정책: server-declared billing owner에게 source별 Google Play/Apple 관리 경로를 제공하고 terms/privacy/configured support를 enum allowlist HTTPS 외부 앱으로만 연다. query/token/user URI를 조립하지 않으며 unavailable composition은 fail closed다.
- 접근성/지역화: 설정 route/tile, EN/KO/EN-XA, locale date/period, scrollable 200% text와 48dp action을 로컬 자동화로 검증했다.
- 검증: focused 26 tests, full Flutter 768 pass + opt-in 1 skip, analyzer fatal issue 0, 477-file format drift 0, codegen 0 output, public config/secret/localization/architecture 계약이 통과했다.
- 후속: D-027 실제 product/price/trial/limits 승인, RevenueCat/Google Play license tester purchase/restore/pending/refund, 실제 manage activity, hosted·실계정·실기기는 마지막 Billing Gate다. Apple은 Android MVP 밖이므로 URL contract만 검증했다.
- Evidence: `docs/evidence/phase-06/WP06_02A_EVIDENCE.md`

### WP06-03 Flutter RevenueCat adapter

- authenticated App User ID
- offerings/purchase/restore
- pending server confirmation
- error mapping
- 상태: **PARTIAL — WP06-03A/B LOCAL IMPLEMENTED (2026-08-08)**
- 구현: provider SDK type이 노출되지 않는 immutable catalog/package, exact authenticated identity bind, purchase/restore result와 retry semantics, exact `purchases_flutter 10.8.0` Android adapter와 app composition
- 권위: Store success와 client snapshot은 Plus를 직접 열지 않으며 current household server entitlement의 newer Plus + billing-owner 확인만 구매를 확정한다.
- 안전성: duplicate action coalescing, bounded confirmation/explicit refresh, store·catalog 장애 시 기존 server entitlement 보존, logout/account/household switch generation invalidation과 identity-clear fail-closed
- SDK 경계: provider import는 infrastructure driver 한 파일에만 두고 exact authenticated custom ID를 검증한다. keyless/non-Android는 unavailable fallback이며 public-key secret/malformed/prod-Test-Store 값을 거부한다.
- 네이티브: Android Play Billing permission을 exact allowlist에 추가하고 dev APK build를 통과했다. SDK diagnostics/automatic device identifier collection은 비활성화한다.
- 후속: paywall UI local slice는 WP06-02A에서 완료했다. 실제 product/price/trial/limits 승인과 RevenueCat·Play account/API key/sandbox/device 검증은 마지막 Billing Gate다. webhook/reconciliation/assignment의 local slice는 WP06-04/05에서 완료됐다.
- Evidence: `docs/evidence/phase-06/WP06_03A_EVIDENCE.md`, `docs/evidence/phase-06/WP06_03B_EVIDENCE.md`

### WP06-04 Webhook/reconciliation

- signature, idempotency, ordering
- transaction/customer upsert
- entitlement materialize
- dead letter/alert
- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- ingress: exact full Authorization + raw-body HMAC-SHA256, 300초 tolerance, 256 KiB bound, event ID/raw hash replay merge와 collision 거부
- reconciliation: metadata-only private inbox, stale assigned-customer periodic schedule, `FOR UPDATE SKIP LOCKED` lease, fixed RevenueCat subscriber endpoint와 strict identity/environment/entitlement/product/subscription mapping
- 권위: webhook은 trigger일 뿐이고 provider request-time normalized event가 WP06-01 service command를 통과해야 entitlement가 바뀐다. active assignment가 없으면 `ASSIGNMENT_REQUIRED`로 닫고 household를 추정하지 않는다.
- 복구/관측: 최대 5 attempts, 1m/5m/30m/2h retry, terminal dead letter, immutable aggregate transition과 queue health 구현. missing-assignment local requeue/remediation은 WP06-05에서 완료했고 hosted alert/operator 도구는 후속 Gate다.
- 검증: Node 18/18, WP06-04 pgTAP 47/47, full JS 115/115, full DB 37 files/2,050, full Flutter 599 pass + opt-in 1 skip와 lint/analyze/format/security/config/codegen 계약 통과
- 후속: explicit first-purchase household intent, missing-assignment requeue와 audited transfer command의 local slice는 WP06-05에서 완료됐다. RevenueCat alias/ownership verification과 RevenueCat/Play account·secret·sandbox·scheduler·실기기는 마지막 Billing Gate다.
- Evidence: `docs/evidence/phase-06/WP06_04_EVIDENCE.md`

### WP06-05 Household assignment/conflicts

- billing household 선택
- purchaser leaves/owner change
- restore conflict
- manual remediation audit
- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- preflight: authenticated Owner/Admin이 purchase/restore 전에 household를 명시적으로 선택하고 30분 provisional binding을 만든다. server가 provider/environment/customer를 파생하며 한 customer↔한 household invariant를 advisory lock으로 직렬화한다.
- 권위: provisional은 Plus가 아니고 verified transaction만 confirmed로 승격한다. cancel/restore-empty/final failure는 client가 만든 provisional만 해제하며 pending/success는 reconciliation을 위해 유지한다.
- 충돌/개인정보: customer/household conflict는 Store 호출 전에 stable state로 닫고 provider/customer/다른 household/billing owner 식별자를 반환하지 않는다. purchaser membership drift도 entitlement를 자동 삭제·이전하지 않고 support-required projection으로 표시한다.
- 복구: valid prepare는 같은 identity/environment의 `ASSIGNMENT_REQUIRED` dead letter를 idempotently requeue한다. periodic repair는 confirmed만 대상으로 하고 expired provisional은 cleanup한다.
- support: Owner/Admin은 aggregate remediation을 요청할 수 있고 service-only resolution은 expected version, allowlisted reason, SHA-256 case-reference와 immutable audit를 요구한다. verified transfer는 source reset + target assignment/entitlement를 원자적으로 적용하며 target conflict를 거부한다.
- Flutter: provider-neutral assignment repository와 strict Supabase mapper를 composition하고 purchase/restore preflight, conflict-no-Store-call, best-effort release와 scope-switch stale-result invalidation을 구현했다.
- 검증: clean local reset, focused Flutter 45/45, focused pgTAP 2 files/68, full Flutter 616 pass + opt-in 1 skip, full DB 39 files/2,118, JavaScript 115/115와 analyzer/lint/format/config/secret/codegen/YAML/matrix/whitespace gates가 통과했다.
- 후속: RevenueCat alias/transfer ownership verification, support operator UI/ticket integration, hosted cleanup과 actual Store account/reinstall/device는 마지막 Billing Gate다.
- Evidence: `docs/evidence/phase-06/WP06_05_EVIDENCE.md`

### WP06-06 Lifecycle/limits

- active/trial/grace/billing issue/expired/refund
- server/client gates
- downgrade data preservation
- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- activation: D-027 수치를 migration에 넣지 않고 active finalized Free/Plus 정책과 expected runtime version을 검증하는 service-only switch 및 immutable policy audit 구현
- gate: active member용 exact aggregate projection과 Flutter provider-neutral domain/RPC mapper 구현. unfinalized/missing policy는 limit을 추정하지 않고 fail closed
- enforcement: active member와 recurring chore/calendar 최초 생성·재활성화를 household+feature advisory lock으로 직렬화하며 one-time과 기존 read/update/cancel/delete는 보존
- lifecycle: trialing/active/grace/billing_issue/expired/revoked client policy와 downgrade over-limit data preservation, localized policy/limit failure를 구현
- 검증: clean 33-migration reset, WP06-06 pgTAP 48/48, full DB 41 files/2,166, Flutter 635 pass + opt-in 1 skip, JavaScript 115/115 + invite 25/25, analyzer/DB lint 통과
- 후속: D-027 실제 Free/Plus 수치와 activation 승인, Store product/price/trial/copy 승인, RevenueCat/Store 실계정·sandbox·실기기는 마지막 Billing Gate다. lifecycle/paywall local UI는 WP06-02A에서 완료했다.
- Evidence: `docs/evidence/phase-06/WP06_06_EVIDENCE.md`

## 자동 검증

- BILLING_TEST_MATRIX
- adapter fake tests
- webhook duplicate/out-of-order/signature
- entitlement RLS/server enforcement
- account/household mapping

## 수동 검증

- Apple sandbox/TestFlight
- Google license tester/internal track
- purchase/restore/reinstall
- pending network loss
- expiry/refund/grace
- price/localization/store copy

## Exit Gate

Store success와 server entitlement가 분리되어도 사용자가 안전한 pending/recovery 경로를 갖고, 다른 account/household에 Plus가 누출되지 않는다.

## Stop/Rollback

mismatch 또는 중복 결제 위험 시 purchase entry를 remote kill switch로 닫고 기존 entitlement read와 support를 유지한다.
