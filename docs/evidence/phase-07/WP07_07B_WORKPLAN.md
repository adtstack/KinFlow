# Phase 07 WP07-07B Public Legal, Support, and Deletion Site Workplan

- 상태: `LOCAL IMPLEMENTED (2026-08-09)` — production publication/G7 완료 아님
- 범위: 기존 Android App Link 공개 자산을 보존하면서 Astro 정적 사이트에 EN/KO 약관·개인정보·지원·계정 삭제 요청 경로를 만들고, 운영 설정이 승인되지 않은 build는 production 게시가 불가능하도록 fail closed한다.
- 제외: 최종 법률 문구 승인, owned production domain/support mailbox, 실제 email 전달·support 운영, hosted 배포, Play Console 등록, 실계정·실browser·screen reader·physical-device 검증

## Requirements and decisions

| 기준 | 구현 계약 |
|---|---|
| `D-005` | 공개 제품·약관·삭제·지원 surface는 Flutter Web이 아니라 Astro 정적 출력이며 JavaScript 없이 읽을 수 있다. |
| `D-036`, `FR-PLAT-001` | `/`, `/terms`, `/privacy`, `/support`, `/delete-account`와 compatibility `/privacy-request`는 같은 문서 안에 EN/KO 본문과 명시적 언어 anchor를 제공한다. |
| `D-040`, `FR-AUTH-008`, `FR-SET-004` | 공개 삭제 경로는 앱 재설치를 요구하지 않고 configured support mailbox로 삭제 요청을 시작한다. body, account email, household/content 또는 token을 URL에 미리 넣지 않는다. |
| `FR-SET-005` | terms/privacy/support를 고정 경로로 노출하고 문서 자체의 policy status, publication date와 policy version을 API contract version과 분리한다. |
| `FR-PLAT-002`, `NFR-A11Y-01` | landmark, skip link, current navigation, visible focus, 최소 48 CSS px action, 200% reflow, reduced-motion와 print 계약을 적용한다. |
| `NFR-SEC-01`, `NFR-PRIV-01` | no form/backend/storage/cookie/analytics/client script이며 CSP·referrer·permissions·frame·MIME 보안 header를 정적 배포 자산으로 제공한다. |

Google Play의 현재 공식 account-deletion guidance는 web resource가 앱 재설치 없이 실제 요청을 시작하게 해야 하며 customer-service email을 허용한다. 이 slice는 새 unauthenticated PII database나 미검증 자동 삭제 endpoint를 만들지 않고 사용자가 명시적으로 여는 email composer를 최소 surface로 사용한다.

## Public route and content contract

- `/`: KinFlow 공개 지원 landing과 terms/privacy/support/deletion 네 destination
- `/terms`: shared-household, account, acceptable use와 subscription 경계를 설명하는 EN/KO legal-review draft
- `/privacy`: 실제 구현에 맞춘 data category, processor, retention/deletion과 user-control 설명의 EN/KO legal-review draft
- `/support`: 사용자 context 자동 첨부가 없는 configured support email과 안전한 문의 작성 지침
- `/delete-account`: 가장 두드러진 external deletion request action, in-app 대안, verification/last-Owner/subscription/shared-data/cancellation 설명
- `/privacy-request`: 기존 `PRIVACY_REQUEST_URL` compatibility path이며 `/delete-account`와 같은 완전한 요청 surface를 렌더링한다.
- `/.well-known/assetlinks.json`: 기존 dev association bytes와 경로를 보존한다.

모든 page는 static HTML/CSS만 사용한다. language 선택은 `#ko`/`#en` anchor로 동작하며 locale query, cookie, local storage 또는 client hydration을 추가하지 않는다.

## Publication configuration

- development 기본값은 `draft`, `noindex`, `.invalid` origin/mailbox와 명시적 비게시 banner다.
- production은 exact 환경 변수 `PUBLIC_SITE_ORIGIN`, `PUBLIC_SUPPORT_EMAIL`, `PUBLIC_DEVELOPER_NAME`, `PUBLIC_LEGAL_ENTITY_NAME`, `PUBLIC_POLICY_VERSION`, `PUBLIC_POLICY_PUBLISHED_ON`, `PUBLIC_POLICY_STATUS=approved`를 요구한다.
- production origin은 HTTPS root origin이어야 하고 user-info/path/query/fragment, localhost와 reserved placeholder host를 거부한다.
- production email은 display-name 없이 단일 mailbox여야 하고 reserved placeholder domain을 거부한다.
- production policy status/date/version은 final legal authority다. 앱/API `CONTRACT_VERSION`에서 파생하지 않는다.
- 환경 변수만으로 초안을 게시할 수 없다. source-controlled `policy-content-manifest.mjs`도 법률 본문 revision과 함께 `approved`로 변경되어야 하며 현재 `draft`는 production build를 거부한다.

## Data, API, dependency, and platform impact

- database migration, Supabase RPC/Edge Function, Flutter route/API, auth session, email provider와 user-data persistence 변경은 없다.
- runtime dependency는 Astro 하나다. 정적 HTML/CSS 생성을 위해서만 사용하며 browser runtime SDK, native permission, tracker와 third-party asset request는 없다.
- 사이트는 별도 package/lockfile을 사용해 Flutter와 server release surface를 분리한다.
- 기존 `public/.well-known/assetlinks.json`과 `.nojekyll`은 build output으로 그대로 복사한다.

## Automated verification

1. exact Astro production build와 TypeScript check
2. 여섯 public route, canonical/title/description, EN/KO landmarks와 current navigation 검증
3. output 전체의 script/form/iframe/external asset/cookie/storage/analytics 부재 검증
4. delete/support mailto가 configured mailbox와 fixed subject만 포함하고 body/identity/content를 포함하지 않는지 검증
5. draft noindex/banner 및 incomplete production configuration fail-closed 검증
6. `_headers`, `robots.txt`, `assetlinks.json`, 404와 internal link target 검증
7. dependency license/vulnerability scan과 repository whitespace/doc/matrix parse

## Manual and deferred evidence

- 최종 terms/privacy/retention/support copy와 policy version은 product/legal owner 승인 전 `draft`다.
- owned HTTPS origin, support mailbox deliverability, abuse/spam handling, support identity verification와 actual deletion handoff는 production Gate다.
- Play Console URL 등록, actual browser email composer, 200% system zoom, keyboard, TalkBack/VoiceOver와 phone/tablet 검증은 사용자 지시대로 마지막 통합 Gate에 둔다.
- 이 local slice를 published legal policy, 실제 삭제 요청 처리 또는 Store compliance 완료로 해석하지 않는다.

## Rollback

- public-site artifact 배포를 중단하거나 마지막 승인 artifact로 되돌려도 앱 내 account deletion/export는 유지된다.
- 삭제 email action을 비활성화해야 하면 production build를 허용하지 않고 기존 요청 mailbox와 server privacy queue는 삭제하지 않는다.
- 기존 dev Android App Link asset은 이 slice와 독립적으로 보존하며 prod signing association은 Play App Signing 확정 전 생성하지 않는다.

## Completion boundary

- static build, exact contract tests, accessibility/security structure와 production configuration denial이 green이면 WP07-07B를 `LOCAL IMPLEMENTED`로 기록한다.
- final legal copy, owned domain/mailbox, hosted request delivery와 Store/browser/device evidence 전에는 WP07-07/G7을 완료하지 않는다.

## Local result

- Astro static build와 type check, 13개 site/config contract, 141개 repository Node 회귀, license/npm/OSV scan과 workflow lint가 통과했다.
- 현재 source-controlled policy content manifest는 의도적으로 `draft`라 production build를 거부하며 development output은 visible draft와 `noindex`를 유지한다.
- 완료 세부 증거와 남은 Gate는 `WP07_07B_EVIDENCE.md`에 기록한다.
