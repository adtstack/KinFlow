# Phase 07 — 개인정보, 보안, 접근성, 글로벌 준비

## 목표

계정/가구 삭제와 내보내기, 보안 hardening, 성인 대상 Store 선언, EN/KO 및 접근성 품질을 Store 제출 수준으로 완성한다.

## Entry

핵심 제품/결제 기능 안정화, 법률/정책 owner 준비.

## Work Packages

### WP07-01 Account deletion

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — G7/출시 완료 아님
- 앱 내 preflight/request/status/cancel과 최근 OAuth 재인증
- 기본 24시간 취소 창, idempotency, optimistic version, leased retry/dead-letter worker
- shared household/chore/calendar 보존과 개인 profile/membership identity tombstone
- last Owner는 transfer/household deletion 전까지 server에서 재검증하여 거부
- endpoint provider material, personal inbox/preference/selection과 local auth/provider/cache 정리
- active Store subscription 자동 취소 금지 안내와 명시적 acknowledgment
- 상세 계약·증적: `docs/contracts/account-deletion.yaml.md`, `docs/evidence/phase-07/WP07_01_EVIDENCE.md`
- 공개 웹 경로, 법률 문구, hosted scheduler와 실계정·Store·실기기 검증은 후속 Gate

### WP07-02A Personal data export

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — G7/출시 완료 아님
- 본인 profile/membership/authored content/participation/notification/billing-summary/privacy-history 범위
- recent OAuth request/download/revoke와 idempotent status/cancel
- leased JSON/TXT generation, private `privacy-exports` Storage와 10 MiB 상한
- hash-only 5분 one-time download, 기본 24시간 artifact expiry, revoke/purge/retry/dead-letter
- exact parser, provider-neutral Flutter controller, EN/KO/EN-XA 설정 화면과 200% text
- 상세 계약·증적: `docs/contracts/data-export.yaml.md`, `docs/evidence/phase-07/WP07_02A_EVIDENCE.md`
- hosted Storage lifecycle/scheduler와 실계정·browser·다중기기·실기기 검증은 마지막 Gate

### WP07-02B Household deletion/export

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — G7/출시 완료 아님
- current Owner server preflight와 recent OAuth request/download/revoke/deletion
- shared-household exact JSON/TXT archive, 파일당 20 MiB, private Storage, hash-only 5분 one-time grant와 기본 24시간 expiry/revoke/purge
- exact-name·구성원 접근·shared-data redaction·active subscription non-cancellation 확인과 24시간 cooling-off cancel
- leased export/purge/deletion worker, service-only retention hold, stale Owner/version fail-close, RLS 선차단, selection/member/invite/endpoint/content redaction과 billing unlink
- provider-independent Flutter domain/repository/controller, Owner-preflight 설정 노출, EN/KO/EN-XA와 200% text
- 상세 계약·증적: `docs/contracts/household-privacy.yaml.md`, `docs/evidence/phase-07/WP07_02B_EVIDENCE.md`
- 다른 구성원 통지·동의·ownership transfer 정책과 최종 법적 보관 정책은 후속 승인 대상
- hosted Storage/scheduler, 실계정·browser·Store·다중기기·실기기 검증은 마지막 Gate
- public deletion request site는 WP07-07과 함께 처리

### WP07-03 Security hardening

- 상태: **WP07-03A LOCAL IMPLEMENTED (2026-08-08)** — WP07-03 전체/G7 완료 아님
- primary 256-bit 초대 링크와 함께 한 번만 표시되는 8-symbol 보조 코드, SHA-256-only DB 저장과 최대 24시간 TTL
- public client-address 및 authenticated user fingerprint별 `10 / 10분` lockout, unknown/expired/revoked/consumed generic `INVITE_INVALID`
- 기존 최소 preview와 idempotent single-use membership transaction을 code flow에서도 재사용
- Flutter 수동 입력, 발급·명시적 copy, 로그인 전후 process-memory continuation, account switch/terminal/accept purge, EN/KO/EN-XA
- 상세 계약·증적: `docs/contracts/invite-short-code.yaml.md`, `docs/evidence/phase-07/WP07_03A_EVIDENCE.md`
- hosted Edge/WAF·NAT/proxy, 실제 성인 2계정과 Android clipboard/keyboard forensic은 마지막 Gate
- threat model review
- secret/dependency/SAST
- deep link/webhook/rate limit
- PII log scrub
- local cache forensic

### WP07-04 Deferred child surface audit

- Managed Child/child mode route·schema·marketing surface가 production에 없음
- feature flag와 analytics taxonomy에 child 행동 수집 없음
- 성인 대상 Store questionnaire와 실제 기능·SDK inventory 일치
- P1 child 계약은 G7 blocker가 아니며 별도 Gate 없이는 활성화 금지

### WP07-05 Accessibility

- screen reader core journey
- 200% text
- contrast/focus/touch
- iPad/tablet orientation
- reduced motion

### WP07-06 Globalization

- 상태: **WP07-06A/B/C/D LOCAL IMPLEMENTED (2026-08-09)** — WP07-06 전체/G7 완료 아님
- 인증된 성인 본인 display name과 nullable 번들 avatar preset, EN/KO locale, 개인 IANA timezone 편집
- active Owner/Admin만 가구 기본 timezone을 변경하고 Member는 read-only로 확인
- profile·active membership 표기·선택적 household timezone을 expected-version 기반 단일 transaction으로 저장하며 private immutable audit 추가
- 성공한 authoritative load/save 직후 app locale 반영, 로그아웃·계정 전환 시 profile state와 locale 격리
- 기존 chore/calendar series timezone과 materialized canonical instant는 재해석하지 않으며 저장 전 영향과 보존 semantics를 확인
- exact provider parser, conflict reload, 중복 제출 차단, EN/KO/EN-XA와 compact 200% text 검증
- 기존 `timezone 0.11.1` IANA database `2025c` 기반의 network-free 지역·도시 검색, current offset/DST 표시, 최대 100건 결정적 결과와 공용 선택기
- 첫 가구·개인 profile·기존 가구·알림 recipient의 네 편집 필드가 같은 read-only 선택기를 사용하며 Store MVP timezone 자유 입력은 0개
- catalog failure·picker cancel은 current draft를 보존하고 retry만 제공하며 실제 create/save는 기존 PostgreSQL catalog가 다시 검증
- profile regional card에서 하나의 UTC instant를 개인·가구 timezone으로 비교하고 미저장 EN/KO·timezone draft와 system 12/24-hour 형식을 즉시 미리보기
- 명시적 새로고침만 새 instant와 offset/DST snapshot을 가져오며 load/refresh 실패와 bundle에 없는 exact identifier는 draft를 보존한 채 fail closed
- 상세 계약·증적: `docs/contracts/profile-preferences.yaml.md`, `docs/contracts/timezone-catalog.yaml.md`, `docs/contracts/timezone-picker-adoption.yaml.md`, `docs/contracts/timezone-date-time-preview.yaml.md`, `docs/evidence/phase-07/WP07_06A_EVIDENCE.md`, `docs/evidence/phase-07/WP07_06B_EVIDENCE.md`, `docs/evidence/phase-07/WP07_06C_EVIDENCE.md`, `docs/evidence/phase-07/WP07_06D_EVIDENCE.md`
- hosted PostgreSQL와 bundle catalog parity, 실제 계정 cross-device/process restart, screen reader·실기기는 마지막 Gate
- EN/KO completion
- pseudo locale
- timezone/locale date
- long text/RTL structural
- store metadata draft

### WP07-07 Public site

- 상태: **WP07-07A APP ENTRY + WP07-07B PUBLIC SITE LOCAL IMPLEMENTED (2026-08-09)** — production publication/G7 완료 아님
- 설정의 별도 Help and legal section과 authenticated terms/privacy/support hub
- fixed public origin `/terms`·`/privacy`, exact configured support의 enum-only HTTPS external launcher
- document-local publication/version authority, informational-only consent boundary와 기존 export/account deletion 바로가기
- EN/KO/EN-XA, live launch 상태, single-flight와 compact 200% text
- 상세 계약·증적: `docs/contracts/legal-support-hub.yaml.md`, `docs/evidence/phase-07/WP07_07A_EVIDENCE.md`
- Astro 7.2.0 static output에 `/`, `/terms`, `/privacy`, `/support`, `/delete-account`, `/privacy-request`와 404/robots/sitemap을 EN/KO로 구현
- 공개 삭제 page는 앱 재설치 없이 configured support email로 실제 요청을 시작하며 fixed subject 외 body·identity·가구/content/token을 URL에 넣지 않음
- browser JavaScript/form/backend/cookie/analytics/external asset 0, skip/current navigation·48px target·200% reflow·reduced motion·CSP/security header를 contract test로 검증
- draft/noindex 기본값과 source-controlled content manifest를 사용해 법률 본문·owned origin/mailbox·정책 version/date 중 하나라도 미승인인 production build를 fail closed
- 기존 dev `/.well-known/assetlinks.json` bytes와 `.nojekyll`을 static output에 보존
- 상세 계약·증적: `docs/contracts/public-site.yaml.md`, `docs/evidence/phase-07/WP07_07B_EVIDENCE.md`
- final legal/retention copy/version, consent 필요성, owned HTTPS/mailbox 배포와 support verification/server handoff, 실browser/screen-reader/실기기는 후속 Gate

### WP07-08 PII-safe diagnostics

- 상태: **LOCAL IMPLEMENTED (2026-08-08)** — G7 완료 아님
- 설정의 authenticated `/settings/diagnostics` route에서 로컬 진단 보고서 preview와 명시적 clipboard copy 제공
- exact 9-key JSON: schema, app ID/version/build, environment, API contract date, coarse platform, random incident UUID v4, UTC 생성 시각
- runtime package metadata와 configured build가 다르면 partial payload 없이 fail closed
- account/household/profile/content/token/network/locale/timezone/device model·serial·advertising ID·signing/installer 정보 제외
- report body는 log/network/DB에 보내지 않고 incident UUID만 PII-free structured correlation에 기록하며 logger 실패 격리
- write-only clipboard, single-flight generation/copy, refresh 실패 시 이전 report 보존, EN/KO/EN-XA와 compact 200% text
- 상세 계약·증적: `docs/contracts/diagnostic-report.yaml.md`, `docs/evidence/phase-07/WP07_08_EVIDENCE.md`
- signed artifact metadata, 실제 Android/iOS clipboard, TalkBack/VoiceOver와 remote Sentry/support correlation은 마지막 Gate

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
- deferred child route/flag 노출 점검
- legal/privacy/store questionnaire review

## Exit Gate

계정 삭제와 공개 요청 경로, data purge/anonymization, accessibility core journey, EN/KO, security review가 승인된다.

## Rollback

삭제 pipeline은 기능 flag로 신규 요청을 일시 중단할 수 있으나 이미 접수된 법적 요청을 잃지 않는다. export URL은 즉시 revoke 가능해야 한다.
