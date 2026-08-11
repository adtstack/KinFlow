# Phase 07 WP07-02A Personal Data Export Workplan

## Status

- 상태: **LOCAL IMPLEMENTED (2026-08-08)**
- 시작일: 2026-08-08
- 완료 증거: `docs/evidence/phase-07/WP07_02A_EVIDENCE.md`
- 수직 조각: settings preflight → recent OAuth authentication → idempotent export request/status/cancel → leased snapshot worker → private JSON/text artifact upload → recent-auth one-time download grant → expiry/revoke purge

## Requirements and decisions

- `FR-SET-003`: machine-readable JSON과 human-readable plain text export를 제공하고 다운로드 접근을 만료시킨다.
- `D-017`: export mutation과 artifact 접근은 online-only다.
- `D-041`: personal account export와 Owner 전용 household export/deletion을 분리한다.
- Store MVP는 adult account만 활성화하므로 deferred child/guardian data는 export producer에 포함하지 않는다.
- personal export는 본인 profile·membership, 본인이 만든 chore/calendar, 본인의 completion/participation, notification preference/inbox metadata, provider identifier가 제거된 billing/privacy summary를 포함한다.
- 다른 구성원의 identity와 다른 사용자가 만든 전체 shared household content는 personal export에 포함하지 않는다. full household export는 WP07-02B Owner flow다.

## Server and data impact

- 기존 `privacy_requests`의 `export` 상태를 활성화하고 export 전용 idempotency, generation job, artifact metadata, download grant, purge job과 immutable audit를 추가한다.
- runtime config는 신규 요청, artifact retention과 download grant TTL을 service-only expected-version command로 관리한다.
- 기본 artifact retention은 24시간, one-time download grant는 5분이며 private `privacy-exports` Storage bucket만 사용한다.
- worker는 bounded `FOR UPDATE SKIP LOCKED` lease로 personal snapshot을 만들고 10 MiB 이하 JSON과 safe plain text를 업로드한 뒤 SHA-256, byte size와 expiry를 기록한다.
- download URL은 raw grant token을 DB에 저장하지 않는다. 최근 OAuth 뒤 hash-only one-time grant를 발급하고 public download function이 원자적으로 consume한 뒤 private object를 stream한다.
- cancel은 processing 전, revoke는 completed artifact에 적용한다. revoke는 미사용 grant를 즉시 무효화하고 purge를 앞당긴다. expiry/revoke object purge는 별도 leased retry/dead-letter 상태다.

## API and Flutter impact

- `data-export` Edge function은 `preflight | status | request | cancel | download | revoke` exact request shapes와 stable redacted envelope만 허용한다.
- `request`, `download`, `revoke`는 access bearer와 별도의 동일 사용자 10분 OAuth proof를 요구한다.
- `data-export-worker`는 dedicated scheduler secret, empty POST와 aggregate-only response를 사용한다.
- `data-export-download`은 짧은 token 한 개만 받아 one-time grant를 consume하고 `no-store`, `nosniff`, `no-referrer`, attachment headers로 JSON/TXT를 stream한다.
- Flutter에는 provider-independent export domain/repository/controller와 URL launcher port, defensive DTO parser, settings route/UI를 추가한다.
- client는 artifact URL이나 export body를 persistent read cache/secure storage에 저장하지 않는다.

## Automated evidence plan

- pgTAP: least privilege/RLS, exact personal scope, other-member/content exclusion, idempotency collision, one pending request, cancel/version, leased generation, completion/failure, hash-only grant, one-time consume, revoke, expiry/purge/retry and immutable audit.
- Node: data-export Edge exact shape/recent-auth/redaction, worker renderer/upload/checksum/cleanup/retry, public download token validation/one-time stream/security headers.
- Flutter: domain invariants, data parser/error mapping, controller recent-auth/request/cancel/revoke/download launch, settings/data-export widget states and 200% pseudo locale.
- 전체 DB/Flutter/JavaScript/analyzer/format/lint/config/secret/codegen/YAML/CSV/whitespace 회귀를 실행한다.

## Manual and deferred evidence

- 실제 Google/Supabase account, hosted Storage object, browser download, multi-device revoke, physical-device Downloads UI와 forensic은 사용자 요청대로 마지막 실계정 Gate에 남긴다.
- Owner full-household export와 household deletion은 WP07-02B, public deletion site는 WP07-07 범위다.
- 최종 legal retention/SLA/copy와 production bucket lifecycle policy는 별도 승인 전 추정하지 않는다. local runtime 기본값은 기술 검증용이다.

## Rollback

- 신규 export 요청은 service-only runtime flag로 중지한다.
- worker scheduler/secret을 비활성화해 generation/purge를 일시 중단하되 request와 audit는 보존한다.
- 모든 active download grant는 runtime disable 또는 artifact revoke로 무효화하고 private objects는 purge queue로 제거한다.
- Flutter route와 세 Edge functions는 hosted rollout 전 독립 제거 가능하다.
- migration은 forward-only이며 이미 생성된 private artifact/hashed grant/audit를 destructive down migration으로 삭제하지 않는다.

## Entry to WP07-02B

- personal export DB/Edge/Flutter focused suites와 전체 회귀가 통과했다.
- JSON/TXT scope가 other-member identity/full household export와 분리되고, one-time download expiry/revoke/purge가 local automation으로 증명됐다.
- 따라서 Owner 전용 household export/deletion의 독립 권한·범위 계약을 시작할 수 있다. hosted/실계정/browser/device 검증은 사용자 순서대로 마지막 Gate에 유지한다.
