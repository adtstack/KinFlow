# 원본 파일 문서화: `contracts/invite-short-code.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/invite-short-code.yaml`
- 원본 형식: `yaml`
- 범위: WP07-03A rate-limited adult household invite short code

```yaml
version: "2026-08-08-wp07-03a"
requirements: [FR-AUTH-004, FR-HH-004, FR-HH-005]
decisions: [D-015, D-017]
relationship:
  primaryCapability: 256-bit high-entropy HTTPS invite link
  shortCodeRole: optional manual-entry companion for the same single-use invite
credential:
  alphabet: "23456789ABCDEFGHJKMNPQRSTVWXYZ"
  normalizedLength: 8
  displayPattern: "XXXX-XXXX"
  normalizedPattern: "^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$"
  acceptedInputNormalization:
    - trim outer whitespace
    - remove ASCII spaces and hyphens
    - uppercase ASCII letters
  rawStorage: forbidden
  databaseMaterial: SHA-256 hash only
  defaultTtlSeconds: 86400
  maximumTtlSeconds: 86400
  mustNotOutlivePrimaryInvite: true
creation:
  authority: current active Owner or Admin, server rechecked
  responseExposure: raw token and formatted short code only when created is true
  idempotentReplayExposure: neither raw token nor short code
preview:
  authentication: public
  exactBody: exactly one of token or shortCode
  shortCodeRateLimit:
    fingerprint: trusted client address material hashed before PostgreSQL
    maximumAttempts: 10
    windowSeconds: 600
  responseFields: [valid, householdDisplayName, inviterDisplayName, role, expiresAt]
  genericShortCodeFailures:
    - unknown
    - expired short code
    - expired primary invite
    - revoked
    - consumed
  stableGenericError: INVITE_INVALID
accept:
  authentication: verified bearer identity
  exactBody: exactly one of token or shortCode, plus optional setActiveHousehold
  idempotency: required
  shortCodeRateLimit:
    fingerprint: authenticated user ID hashed before PostgreSQL
    maximumAttempts: 10
    windowSeconds: 600
  transaction: existing single-use membership and active-household acceptance command
client:
  continuationStorage: process memory only
  forbiddenStorage: [URL, query, route state, secure storage, read cache, analytics, logs]
  purgeEvents: [account switch, terminal failure, acceptance, explicit clear]
  clipboard: only after explicit user copy action
  localization: [EN, KO, EN-XA]
rollback:
  preservePrimaryLinkFlow: true
  edgeCodeBranchCanBeDisabled: true
  migration: forward-only
deferred:
  - hosted Edge and WAF distributed abuse validation
  - real-account two-adult acceptance
  - proxy and NAT address behavior
  - Android keyboard and clipboard forensic
  - email or SMS code delivery
```
