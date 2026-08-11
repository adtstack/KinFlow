# 원본 파일 문서화: `contracts/public-site.yaml`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `contracts/public-site.yaml`
- 원본 형식: `yaml`
- 범위: WP07-07B Astro 정적 legal/privacy/support/public account-deletion request site

```yaml
version: "2026-08-09-wp07-07b"
requirements:
  - FR-AUTH-008
  - FR-SET-004
  - FR-SET-005
  - FR-PLAT-001
  - FR-PLAT-002
  - NFR-A11Y-01
  - NFR-I18N-01
  - NFR-SEC-01
  - NFR-PRIV-01
decisions: [D-005, D-036, D-040, D-041]
rendering:
  framework: Astro
  output: static
  browserJavaScript: forbidden
  externalAssets: forbidden
  analyticsCookiesStorage: forbidden
routes:
  landing: "/"
  terms: "/terms"
  privacy: "/privacy"
  support: "/support"
  accountDeletion: "/delete-account"
  accountDeletionCompatibility: "/privacy-request"
  androidAssociation: "/.well-known/assetlinks.json"
  notFound: "/404.html"
localization:
  languages: [ko, en]
  defaultDocumentLanguage: ko
  selector: document anchors only
  queryCookieOrLocalStorage: forbidden
publication:
  development:
    policyStatus: draft
    robots: noindex, nofollow
    visibleNonPublicationBanner: required
    reservedOriginAndMailbox: allowed
  production:
    policyStatus: approved
    sourceControlledContentManifest: approved
    requiredConfiguration:
      - PUBLIC_SITE_ORIGIN
      - PUBLIC_SUPPORT_EMAIL
      - PUBLIC_DEVELOPER_NAME
      - PUBLIC_LEGAL_ENTITY_NAME
      - PUBLIC_POLICY_VERSION
      - PUBLIC_POLICY_PUBLISHED_ON
    siteOrigin:
      scheme: https
      rootPathOnly: true
      userInfoQueryFragment: forbidden
      localhostOrReservedPlaceholder: forbidden
    supportEmail:
      oneMailboxOnly: true
      displayName: forbidden
      reservedPlaceholderDomain: forbidden
    legalVersionAuthority: public policy document
    apiContractVersionAsLegalVersion: forbidden
deletionRequest:
  authority: configured support mailbox
  appInstallationRequired: false
  transport: user-initiated mailto
  prefilledFields: [fixed subject]
  forbiddenPrefilledFields:
    - body
    - account email
    - auth user, household, or member identifier
    - household content or person name
    - token, receipt, diagnostic, or billing identifier
  immediateDeletion: false
  ownershipVerificationBeforeServerRequest: required
  disclosures:
    - shared household data and personal identity are handled separately
    - last Owner must transfer ownership or delete the household first
    - Store subscription is not automatically cancelled
    - default in-app cancellation window is 24 hours before processing
support:
  automaticallyAttachedContext: []
  safeGuidance:
    - issue category and coarse steps only
    - optional PII-safe diagnostic incident ID
  forbiddenGuidance:
    - password, OAuth code, JWT, invite token, endpoint token, or receipt
    - household names, chore titles, calendar content, or other member identity
securityHeaders:
  required:
    - Content-Security-Policy
    - Referrer-Policy
    - X-Content-Type-Options
    - X-Frame-Options
    - Permissions-Policy
    - Strict-Transport-Security
  csp:
    default-src: none
    style-src: self
    img-src: self data
    base-uri: none
    form-action: none
    frame-ancestors: none
accessibility:
  skipLink: required
  landmarks: [header, nav, main, footer]
  currentNavigation: aria-current page
  minimumActionTargetCssPixels: 48
  visibleKeyboardFocus: required
  zoomReflowPercent: 200
  reducedMotion: respected
  semanticLanguageRegions: required
privacy:
  backendOrForm: none
  requestDatabase: none
  thirdPartyNetworkRequest: none
  cookieOrBrowserStorage: none
  userInputEcho: none
compatibility:
  preserveAndroidAssetLinksBytes: true
  preserveNoJekyllMarker: true
  fixedAppLegalPaths: [terms, privacy]
rollback:
  staticArtifactCanBeWithdrawn: true
  inAppPrivacyFlowsRemainAvailable: true
  devAndroidAssociationIndependent: true
deferred:
  - final legal and retention approval
  - owned production domain and support mailbox
  - hosted deployment and mailbox deliverability
  - support verification and server deletion handoff
  - Play Console, real browser, assistive technology, and physical-device evidence
```
