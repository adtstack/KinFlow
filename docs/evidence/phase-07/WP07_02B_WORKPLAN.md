# Phase 07 WP07-02B Owner Household Export and Deletion Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — hosted/실계정 마지막 Gate 대기
- 시작일: 2026-08-08
- 수직 조각: Owner preflight → recent OAuth → full shared-household JSON/TXT export → private one-time download → exact-name/impact-confirmed deletion request → cooling-off cancel → leased access revocation/redaction/billing unlink → status and immutable audit

## Requirements and decisions

- `FR-HH-009`: 가구 삭제는 현재 Owner만 요청하며 모든 구성원 영향 확인과 background 상태를 제공한다.
- `FR-AUTH-006`: household export request/download/revoke와 deletion request는 동일 사용자 최근 OAuth 재인증을 요구한다.
- `FR-SET-003`: Owner가 관리하는 shared household archive를 machine-readable JSON과 human-readable text로 받을 수 있고 download 접근은 만료된다.
- `D-017`: export/delete mutation과 artifact 접근은 online-only다.
- `D-041`: household deletion은 account deletion과 분리한다. 구성원의 Auth account/profile과 다른 household membership은 삭제하지 않는다.
- `D-048`: 생성/취소/회수 mutation은 idempotency와 optimistic version을 사용한다.
- `D-049`: 삭제 완료 시 모든 구성원의 active-household selection, endpoint binding과 local scope가 재조정될 수 있는 server state를 만든다.

## Household export boundary

- 포함: household metadata, active member roster, chore series/revisions/occurrences/actions, calendar series/revisions/occurrences/exceptions/participation, aggregate notification configuration, provider-ID-free billing summary와 household privacy-request history.
- 제외: member email·OAuth/provider identity·personal profile, 개인 notification inbox/read state, endpoint token/ciphertext/fingerprint/proof, billing customer/transaction/receipt/product/provider identifier, 다른 household 데이터.
- removed member의 과거 activity는 opaque member ID snapshot으로만 남기고 removed member display name/profile identity는 archive에 넣지 않는다.
- artifact는 private `privacy-exports` bucket의 household 전용 prefix에 JSON/TXT 각각 최대 20 MiB로 저장한다.
- raw download token은 DB에 저장하지 않고 SHA-256 hash-only 5분 one-time grant를 사용한다. artifact 기본 retention은 24시간이다.

## Household deletion boundary

- request 시 current Owner pointer/role, household version, exact current household name, shared-data/member-access acknowledgment와 active subscription acknowledgment를 transaction에서 재검증한다.
- 기본 cooling-off는 24시간이고 queued/verifying 동안 expected-version cancel이 가능하다.
- worker claim 직전에 requester가 여전히 current Owner인지 재검증한다. ownership 변경·이미 삭제된 household는 fail closed다.
- 완료 transaction은 household를 deleted 처리하고 모든 active membership/active-household selection을 종료해 old JWT RLS 접근을 즉시 차단한다.
- household/member name·avatar, chore/calendar title/description/creator와 notification endpoint cryptographic material을 tombstone/redact한다.
- invite는 revoke하고 개인 notification preference/inbox는 inactive 처리한다. immutable content-free audit/job history와 recurrence/completion references는 legal/operational retention 대상으로 분리한다.
- active billing assignment와 entitlement는 household에서 unlink/end 처리하지만 Store subscription/provider customer/receipt/history를 자동 취소하거나 삭제하지 않는다.
- service-only retention hold는 claim 전에 deletion을 정지하고 사용자 status에는 hold 여부와 review 시각만 노출한다. hold reason/operator identity는 public response에서 제외한다.

## API and Flutter impact

- `household-privacy` Edge function은 `preflight | status | requestExport | cancelExport | downloadExport | revokeExport | requestDeletion | cancelDeletion` exact request shapes만 허용한다.
- 모든 operation은 verified bearer identity를 사용하며 request body의 user/role 값을 신뢰하지 않는다.
- export request/download/revoke와 deletion request는 access bearer와 별도의 같은 사용자 최대 10분 OAuth proof를 요구한다.
- `household-export-download`은 one-time token을 원자 consume하고 private object의 path/size/SHA-256 검증 뒤 `no-store` attachment로 stream한다.
- `household-privacy-worker`는 dedicated secret, empty POST와 aggregate-only counters를 사용해 generation, artifact purge와 household deletion을 bounded lease로 처리한다.
- Flutter는 provider-independent domain/repository/controller를 사용하고 기존 `DataExportDownloadLauncher` port로 URL만 즉시 전달한다. URL/export body를 state·cache·secure storage에 저장하지 않는다.
- settings에는 Owner에게만 household privacy row를 표시하고 preflight에서 server authorization이 실패하면 fail closed한다.

## Automated evidence plan

- pgTAP: Owner/Admin/Member authorization, ownership/version/name race, cross-household injection, pending/idempotency, export exact scope/exclusions, grants, expiry/revoke/purge, cooling-off/cancel, retention hold, competing worker claim, membership/RLS revocation, redaction, billing unlink/history preservation와 immutable audit.
- Node: exact Edge shapes/recent-auth/redaction, full archive renderer/upload/checksum/cleanup, one-time download/security headers와 worker retry/aggregate response.
- Flutter: domain invariants, exact DTO/error mapping, owner preflight, export/download/revoke, deletion confirmation/cancel/status, settings visibility, localized 200% pseudo widget와 local scope invalidation handoff.
- focused suites 이후 전체 DB/JavaScript/Flutter/analyzer/format/lint/config/secret/codegen/YAML/CSV/whitespace 회귀를 실행한다.

## Manual and deferred evidence

- 실제 Google/Supabase account, hosted Storage/function/scheduler, browser download residue, Store subscription, multi-device와 physical-device forensic은 사용자 요청대로 마지막 실계정 Gate에 남긴다.
- 최종 legal retention 기간·hold 사유·operator policy, 다른 구성원 사전 통지/동의 문구와 production object lifecycle은 승인 전 추정하지 않는다.
- public deletion request site는 WP07-07 범위다.

## Rollback

- service-only runtime flag로 신규 household export/deletion과 download grant 발급을 각각 중지한다.
- scheduler/worker secret을 비활성화해 generation/deletion/purge를 중단하되 queued request와 immutable audit를 보존한다.
- active artifact는 revoke하고 purge queue를 drain한다. deletion은 processing 전에 cancel하거나 retention hold로 정지할 수 있다.
- access revocation/redaction과 billing unlink가 완료된 household는 code rollback으로 복구하지 않는다. migration은 forward-only이며 audit/tombstone을 삭제하지 않는다.
- hosted rollout 전 Flutter route/composition과 세 Edge functions는 독립 제거 가능하다.

## Entry to WP07-03

- Owner authorization·cross-household denial, full archive boundary, one-time download와 deletion cooling-off/retention/access-revocation/redaction/billing-unlink가 local DB/Edge/Flutter 자동화로 증명되어야 한다.
- hosted/real-account/browser/device 항목은 별도 마지막 Gate로 명시되어야 한다.
