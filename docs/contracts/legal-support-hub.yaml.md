# 원본 파일 문서화: `contracts/legal-support-hub.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/legal-support-hub.yaml`
- 원본 형식: `yaml`
- 범위: WP07-07A in-app legal, privacy, and support hub

```yaml
version: "2026-08-08-wp07-07a"
requirements: [FR-SET-003, FR-SET-004, FR-SET-005, FR-PLAT-001, FR-PLAT-002]
decisions: [D-005, D-013]
authority:
  legalDocumentBody: public static site
  legalDocumentPublicationAndVersion: the linked document itself
  apiContractVersionAsLegalVersion: forbidden
  consentRequirement: product and legal approval
destinations:
  input: enum only
  terms: public site origin plus /terms
  privacy: public site origin plus /privacy
  support: configured support URI
  launchMode: external application
  userSuppliedUri: forbidden
  queryOrTokenAugmentation: forbidden
uriPolicy:
  scheme: https
  host: required
  userInfo: forbidden
  query: forbidden
  fragment: forbidden
  publicDocumentBasePathInheritance: forbidden
privacy:
  automaticallyAttachedToSupport: []
  forbiddenSupportContext:
    - auth user ID
    - household or member ID
    - email or profile fields
    - household content
    - billing identifiers
    - diagnostic identifiers
consent:
  currentHub: informational only
  mutation: none
  clientInsertIntoConsentRecords: forbidden
  futureGate:
    - approved consent type and exact policy version
    - server-mediated current-user authorization
    - grant, withdrawal, and not-required semantics
    - immutable audit and approved retention
states: [idle, opening, opened, unavailable]
concurrency:
  externalLaunch: single flight
  duplicateTap: ignored while opening
internalPrivacyRoutes: [personal data export, account deletion]
client:
  localization: [EN, KO, EN-XA]
  compactTextScale: 200 percent scrollable
  minimumActionTarget: 48 dp
  statusAnnouncement: accessibility live region
rollback:
  routeCanBeRemoved: true
  unavailableLauncherFailsClosed: true
  privacyAndAccountFlowsPreserved: true
deferred:
  - final legal copy and publication versions
  - owned HTTPS public-site deployment
  - support SLA and production destination
  - determination and implementation of any versioned consent
  - real browser, offline network, screen-reader, and physical-device validation
```
