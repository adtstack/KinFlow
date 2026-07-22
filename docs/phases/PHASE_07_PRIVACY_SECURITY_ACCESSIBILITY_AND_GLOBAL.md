# Phase 07 — 개인정보, 보안, 접근성, 글로벌 준비

## 목표

계정/가구 삭제와 내보내기, 보안 hardening, Managed Child 보호, EN/KO 및 접근성 품질을 Store 제출 수준으로 완성한다.

## Entry

핵심 제품/결제 기능 안정화, 법률/정책 owner 준비.

## Work Packages

### WP07-01 Account deletion

- in-app request/status/cancel 가능 범위
- shared data anonymize/tombstone
- last Owner resolution
- token/device/cache cleanup
- active subscription 안내

### WP07-02 Household deletion/export

- Owner authorization
- async job/status
- short-lived download
- retention/audit
- public deletion request site

### WP07-03 Security hardening

- threat model review
- secret/dependency/SAST
- deep link/webhook/rate limit
- PII log scrub
- local cache forensic

### WP07-04 Child safety

- parental gate brute force/recovery
- child mode analytics off
- route/action bypass
- policy copy and guardian control

### WP07-05 Accessibility

- screen reader core journey
- 200% text
- contrast/focus/touch
- iPad/tablet orientation
- reduced motion

### WP07-06 Globalization

- EN/KO completion
- pseudo locale
- timezone/locale date
- long text/RTL structural
- store metadata draft

### WP07-07 Public site

- Astro static pages
- privacy/terms/support/deletion
- accessible/SEO/readable without JS

## 자동 검증

- deletion/export state tests
- security scans
- PII log fixtures
- localization key coverage
- widget semantics/golden selective
- public site link/form tests

## 수동 검증

- full deletion on two accounts/last Owner
- export content/access expiry
- VoiceOver/TalkBack journey
- child gate bypass attempts
- legal/privacy/store questionnaire review

## Exit Gate

계정 삭제와 공개 요청 경로, data purge/anonymization, accessibility core journey, EN/KO, security review가 승인된다.

## Rollback

삭제 pipeline은 기능 flag로 신규 요청을 일시 중단할 수 있으나 이미 접수된 법적 요청을 잃지 않는다. export URL은 즉시 revoke 가능해야 한다.
