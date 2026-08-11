# Phase 07 WP07-07B Public Legal, Support, and Account Deletion Site Evidence

## 결과

- 상태: **LOCAL IMPLEMENTED (2026-08-09)** — WP07-07 전체, publication과 G7 완료는 아님
- 범위: 기존 dev Android association을 보존한 Astro EN/KO no-JS public site, terms/privacy/support/account-deletion routes, external email deletion request, accessibility/security/static publication contract
- 제외: 최종 법률·retention 승인, owned origin/mailbox, 실제 email 전달·support verification/server handoff, hosted deployment, Play Console, 실browser·assistive technology·physical-device evidence
- database migration, Supabase/Edge/Auth, Flutter source, user-data persistence와 browser runtime SDK 변경: **없음**

## Requirements

| 기준 | 로컬 결과 |
|---|---|
| `D-005` | PASS — Astro 7.2.0 static output이며 생성 artifact에 browser JavaScript, form, iframe, external asset가 없다. |
| `D-036`, `FR-PLAT-001`, `NFR-I18N-01` | PASS FOR PUBLIC SITE / OVERALL PARTIAL — 모든 user route에 semantic KO/EN region과 anchor language navigation이 있으며 query, cookie, local storage가 없다. 전체 app/store device review는 남았다. |
| `D-040`, `FR-AUTH-008`, `FR-SET-004`, `NFR-DEL-01` | PASS FOR LOCAL PUBLIC REQUEST PATH / OVERALL PARTIAL — 앱 재설치 없이 fixed configured support mailbox로 요청을 시작한다. 실제 mailbox verification과 server request handoff는 남았다. |
| `FR-SET-005`, `FR-PLAT-006` | PASS FOR IMPLEMENTATION-ALIGNED DRAFT / OVERALL PARTIAL — terms/privacy/support를 fixed routes에 제공하고 policy version을 API contract에서 분리한다. final legal/Store disclosure 승인은 남았다. |
| `FR-PLAT-002`, `NFR-A11Y-01` | PASS FOR STATIC STRUCTURE / OVERALL PARTIAL — skip link, landmarks, current navigation, visible focus, 48 CSS px action, 200% reflow structure, reduced-motion와 print 계약을 자동 검증했다. 실제 screen reader/browser zoom/contrast device review는 남았다. |
| `NFR-SEC-01`, `NFR-PRIV-01` | PASS FOR NEW SURFACE — CSP, no-referrer, MIME/frame/permission/HSTS header와 no script/form/backend/cookie/analytics/storage를 적용했다. mailto에는 fixed subject 외 body·identity·content가 없다. |

Google Play의 현재 공식 account-deletion guidance는 web resource가 앱 재설치 없이 실제 요청을 시작해야 하며 customer-service email을 허용한다. 이 slice는 그 최소 경로를 사용하고 unauthenticated PII form/database나 자동 삭제 authority를 새로 만들지 않았다.

## Public routes and request behavior

- `/`: public resource landing, 서비스 식별, terms/privacy/support/deletion 진입과 no-tracking 설명
- `/terms`: 계정·성인 대상·가구 역할·shared content·Google Play 구독·종료 경계의 EN/KO draft
- `/privacy`: 실제 구현 기반 account/profile/household/notification/subscription/operation data category, processor, sharing, export/deletion과 adult scope의 EN/KO draft
- `/support`: configured mailbox와 safe/forbidden support context. fixed `KinFlow support request` subject만 사용
- `/delete-account`: 가장 두드러진 web request action, ownership verification, last Owner, Store non-cancellation, 기본 24시간 cancellation, personal/shared data 분리 설명
- `/privacy-request`: 기존 `PRIVACY_REQUEST_URL` compatibility path에서 같은 완전한 deletion surface를 렌더링
- `/404.html`, `/robots.txt`, `/sitemap.xml`: static recovery와 draft/production search policy
- `/.well-known/assetlinks.json`, `.nojekyll`: source bytes를 build output에 그대로 보존

삭제 mailto는 `mailto:<configured mailbox>?subject=KinFlow%20account%20deletion%20request` exact shape다. body, account email, user/household/member ID, 가족 콘텐츠, token, receipt 또는 diagnostic identifier를 URL에 넣지 않는다. 사용자가 email composer에서 명시적으로 보내기 전까지 데이터 전송은 없다. 실제 삭제 queue는 support가 소유권과 차단 조건을 확인한 뒤 기존 server-authoritative flow로 넘겨야 하며 이 live handoff를 로컬 static site가 완료로 주장하지 않는다.

## Publication fail-closed

- development 기본값은 `.invalid` origin/mailbox, `draft`, visible bilingual non-publication banner와 `noindex, nofollow`다.
- production은 HTTPS root origin, one-mailbox support address, developer/legal entity, independent policy version/date와 `PUBLIC_POLICY_STATUS=approved`를 모두 요구한다.
- credential/path/query/fragment/port가 있는 origin, localhost/reserved placeholder, display-name/injected/reserved mailbox, placeholder name/version와 invalid date를 거부한다.
- 환경 변수만 `approved`로 바꿀 수 없다. source-controlled `policy-content-manifest.mjs`도 approved revision이어야 한다. 현재 manifest는 `2026-08-09-wp07-07b-draft-1 / draft`라 production build가 의도적으로 실패한다.
- final legal copy를 승인할 때 본문 변경, manifest revision/status와 production values를 같은 review에서 갱신해야 한다. API `CONTRACT_VERSION`을 legal version으로 재사용하지 않는다.

## Automated validation

| 검증 | 결과 |
|---|---|
| Public site full gate `npm test` | PASS — static build 7 HTML pages + robots/sitemap, Astro check 20 files issue 0, Node contract 13/13 |
| Route/static privacy contract | PASS — 6 public user routes + 404, internal links/canonical/KO/EN/draft state, script/form/iframe/input/inline-handler/external runtime asset 0 |
| Deletion/support contract | PASS — exact configured mailto, fixed subject only, body/cc/bcc/identity/content/token/receipt 0, public no-app request and blocker disclosures present |
| Accessibility/security contract | PASS — skip/current navigation, semantic language regions, 48px action, focus/reduced-motion/print, CSP/header/robots/sitemap present |
| Output budget | PASS — complete development artifact 100 KiB; largest HTML 11,325 bytes, CSS 6,810 bytes, browser JavaScript 0 bytes |
| Production configuration negative path | PASS — missing/invalid authority와 source content `draft`가 fail closed; approved manifest/config shape는 pure unit으로 검증하고 실제 production artifact는 생성·게시하지 않음 |
| Root Node regression `npm run ci:test` | PASS — 141 tests / failure 0; existing Android Asset Links and new build-only dependency contract 포함 |
| Workflow contract + actionlint | PASS — 5 jobs, 17 pinned action uses, contents read-only; exact actionlint issue 0; quality job에 safe public-site `npm ci` + `npm test` 추가 |
| License audit | PASS — 167 Pub, 15 npm runtime, 365 deduplicated public-site build-only packages; site lock의 모든 dependency가 `dev: true`이며 browser runtime package 0 |
| Registry audit | PASS — npm audit info/low/moderate/high/critical 0 across 367 resolved build packages |
| Fixed offline OSV | PASS — exact scanner 2.3.8; root npm 15 + public-site npm 365 + Pub 172 lock packages, vulnerability failure 0 |
| Secret scan | PASS — exact Dart 3.12.2 `--suppress-analytics`, high-confidence secret 0 |
| Contract parse | PASS — fenced `public-site.yaml`, exact version/routes/content-manifest authority |
| Matrix parse | PASS — 13 fenced CSV documents; requirements 116×18, tests 78×11 |
| Whitespace | PASS — targeted `git diff --check`, issue 0 |

첫 secret-scan 시도 둘은 scanner 본문이 아니라 Dart CLI telemetry session file의 sandboxed home write에서 종료했다. 같은 exact Dart에 `--suppress-analytics`를 전달해 재실행한 결과 high-confidence secret 0으로 통과했다. 제품 코드 실패로 계산하지 않는다.

## Dependency and artifact boundary

- Astro, `@astrojs/check`와 TypeScript는 별도 `apps/public_site/package-lock.json`에 exact pin된 build-only dev dependency다.
- Astro optional image pipeline의 libvips package를 포함한 build-only SPDX는 별도 reviewed allowlist에 기록한다. 현재 site는 image pipeline을 사용하지 않고 이 package code/binary를 static artifact에 배포하지 않는다.
- build artifact는 HTML, 한 hashed CSS, text/XML/header와 기존 Android association JSON뿐이다. browser JavaScript, web font, image, native permission, SDK, source map과 credential은 없다.
- CI offline OSV가 site lock을 독립 입력으로 읽고 license audit은 non-dev site dependency가 하나라도 생기면 실패한다.

## Security and privacy review

- public page는 사용자 입력을 받거나 반사하지 않고 backend endpoint를 호출하지 않는다. CSRF, unauthenticated deletion mutation과 public PII database surface가 없다.
- support/deletion mailbox는 public configuration이며 secret이 아니다. email link에 sender/account identity나 page/app context를 자동 첨부하지 않는다.
- support copy는 password, OAuth code, JWT, invite/push token, purchase receipt, 가족 이름/집안일/일정/다른 구성원 identity를 보내지 말라고 EN/KO로 안내한다.
- CSP는 default deny이며 style/image self만 허용하고 base/form/frame을 차단한다. `_headers`는 referrer, MIME, frame, permissions, cross-origin과 HSTS를 추가한다.
- draft build는 noindex이며 policy content approval과 production configuration은 source/environment의 독립 Gate다.
- 새 analytics event, cookie, local/session storage, service worker, third-party request 또는 log field가 없다.

## Manual and deferred validation

사용자 우선순위에 따라 다음 항목은 **NOT RUN / 마지막 통합 Gate**다.

- 법률·제품 owner의 final terms/privacy/retention/operator copy, policy version과 consent 필요성 승인
- owned production HTTPS origin, DNS/TLS/redirect/content-type/CSP/header/caching/robots와 actual deploy rollback
- production support mailbox deliverability, spam/abuse control, response SLA, identity verification와 existing account-deletion request handoff
- 실제 Google/Supabase account의 web request → verification → status/cancel → tombstone/session revoke lifecycle
- Play Console public deletion/privacy/support URL과 Data Safety/SDK inventory declaration
- Chrome/Android browser email composer, no-mail-client fallback, keyboard, 200% browser/system zoom, TalkBack/VoiceOver, phone/tablet/split-screen

Sites hosting은 final legal copy, owned origin/mailbox와 external publication authority가 없는 현재 범위를 넘으므로 실행하지 않았다. local build를 public publication 또는 Store compliance 완료로 해석하지 않는다.

## Remaining risks and completion boundary

1. email은 사용자가 명시적으로 sender identity와 본문을 보내는 외부 시스템이다. mailbox access control, retention, abuse 대응과 secure verification runbook이 승인되어야 한다.
2. support가 verified email을 기존 Edge request로 전환하는 operator surface는 아직 구현하지 않았다. 수동 service-role mutation을 임의로 추가하지 않는다.
3. terms/privacy 내용은 구현과 현재 결정을 반영한 draft지만 법률 자문이 아니며 retention period, 책임·분쟁·운영자 주소는 확정되지 않았다.
4. static contract는 semantic structure와 reflow CSS를 증명하지만 screen reader announcement order, browser contrast rendering과 실제 email app behavior를 증명하지 않는다.
5. WP07-07B local slice는 완료했지만 WP07-07/G7은 source manifest가 draft이고 hosted/live evidence가 없어 계속 `PARTIAL`이다.

## Rollback

- static artifact 배포를 중지하거나 마지막 approved artifact로 되돌려도 앱 내 export/account-deletion과 server privacy queue는 유지된다.
- public request를 열 수 없으면 production build를 차단하고 mailbox/queued request/audit를 삭제하지 않는다.
- Astro route를 제거해도 existing app legal-support launcher의 unavailable fail-closed와 privacy routes는 유지된다.
- dev `assetlinks.json`은 site route와 독립 보존한다. prod signing association은 Play App Signing certificate 전에는 추가하지 않는다.
- DB/API migration이 없어 data rollback은 없다.

## Next entry condition

- 기능 우선순위의 다음 locally testable slice는 WP07-06B searchable IANA timezone selection UX다. 기존 server-authoritative validation과 recurrence instant 보존을 유지하면서 free-text 입력 오류를 줄인다.
- final legal/site publication, 실제 계정, hosted mailbox, browser와 physical-device 검증은 사용자 지시대로 기능 개발 대부분이 끝난 뒤 마지막 통합 Gate에 유지한다.
