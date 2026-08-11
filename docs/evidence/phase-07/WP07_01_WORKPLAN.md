# Phase 07 WP07-01 Account Deletion Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- 시작일: 2026-08-08
- 수직 조각: 앱 내 account-deletion preflight → recent OAuth authentication → idempotent request/status/cancel → delayed worker claim → shared-data tombstone/device-token erasure → Supabase Auth irreversible soft-delete → local sign-out/cache purge

## Requirements and decisions

- `FR-AUTH-006`: 계정 삭제 전에 최근 인증을 재검증한다.
- `FR-AUTH-008`: 앱 내 요청, 상태 추적, 세션 무효화와 후속 공개 웹 경로를 제공한다.
- `FR-SET-004`: 상태·보관 예외를 설명하고 token/device/local state를 정리한다.
- `D-017`: 삭제 mutation은 online-only다.
- `D-040`: 앱 내 시작과 공개 웹 요청 경로를 모두 제공한다. 이 WP는 앱 경로를 구현하고 공개 웹은 WP07-07에 남긴다.
- `D-041`: account deletion과 household deletion을 분리한다. active Owner membership이 하나라도 있으면 transfer 또는 별도 household deletion 전까지 account deletion을 거부한다.
- `D-049`: 사용자 전환/삭제 시 cache, push binding과 provider identity를 정리한다.

## Server and data impact

- 새 `privacy_request_type`, `privacy_request_status`, `privacy_requests`와 private idempotency/job/audit tables를 추가한다.
- 신규 요청 pause와 cancellation window는 versioned service-only runtime config로 관리한다. 기본 취소 창은 24시간이다.
- account deletion은 shared household/chore/calendar history를 삭제하지 않는다. non-Owner membership을 removed tombstone으로 전환하고 display/avatar identity를 최소화한다.
- notification endpoint의 encrypted provider token, fingerprint와 revocation proof를 복구 불가능한 tombstone material로 교체하고 active invite/personal notification preference/inbox를 정리한다.
- active billing assignment는 삭제하지 않는다. request 전 사용자에게 Store subscription이 자동 취소되지 않음을 명시하고 acknowledgment를 강제한다.
- worker는 tombstone transaction 뒤 Supabase Auth Admin irreversible soft-delete를 호출한다. 기존 billing/audit FK는 auth row가 유지되는 soft-delete 특성으로 보존한다.
- completed/deleted profile은 old access token이 남아 있어도 profile, membership, billing-owner RLS를 사용할 수 없도록 server authorization을 fail closed로 바꾼다.

## API and Flutter impact

- `account-deletion` Edge function은 `preflight | status | request | cancel` exact request shapes와 stable error envelope만 허용한다.
- `request`는 bearer identity와 별도로 최근 10분 OAuth `amr` access-token proof를 검증한다.
- `account-deletion-worker`는 dedicated scheduler secret, empty POST, bounded SKIP LOCKED claims와 retry/dead-letter semantics를 사용한다.
- Flutter에 provider-independent privacy domain/repository/controller, defensive Edge DTO parser, 설정 및 계정 삭제 화면을 추가한다.
- 요청 접수 직후 기존 auth lifecycle logout을 호출해 remote endpoint revoke, RevenueCat/Google identity reset과 encrypted local cache purge를 수행한다.

## Automated evidence plan

- pgTAP: least privilege/RLS, preflight, recent-auth mediated request RPC, idempotency collision, pending uniqueness, active-subscription acknowledgment, last-Owner block, cancellation, delayed/serialized claim, tombstone preservation, endpoint material erasure, retry/completion, immutable audit.
- Node: Edge exact shape/recent-auth/error redaction과 worker auth/claim/soft-delete/retry contract.
- Flutter: domain invariants, data parser/error mapping, repository mapping, controller recent-auth/request/cancel, settings/account-deletion widget semantics and logout handoff.
- 전체 DB/Flutter/JavaScript/analyzer/format/lint/secret scan 회귀를 실행한다.

## Manual and deferred evidence

- 실제 Google/Supabase account soft-delete, multi-device session expiration, Play subscription management, hosted scheduler와 provider/device token inspection은 사용자 요청대로 마지막 실계정 검증 Gate에 남긴다.
- WP07-07 public deletion request site와 법률 문구 승인은 별도 Work Package다.

## Rollback

- 신규 요청은 service-only runtime flag로 즉시 중지한다.
- worker scheduler/secret을 비활성화하면 queued legal request와 audit를 잃지 않고 처리를 일시 중단할 수 있다.
- Flutter route/composition과 Edge functions는 독립 제거 가능하다.
- migration은 forward-only다. 이미 tombstone/soft-delete된 identity를 복원하지 않으며, 코드 rollback은 queued request를 삭제하지 않는다.

## Entry to WP07-02

- WP07-01 DB/Edge/Flutter focused suites와 전체 회귀가 통과하고, account deletion이 household deletion/export와 명확히 분리되며, 실제 계정 검증 항목이 증적에 명시되어야 한다.
- 위 local entry 조건은 `WP07_01_EVIDENCE.md`로 충족했다. G7/출시 완료는 아니며 공개 웹과 실계정 검증은 계속 남는다.
