# Supabase Local Backend

WP01-04의 local-only Supabase baseline을 WP02-02 household authorization boundary까지 확장한 개발 환경이다. production project와 연결하거나 실제 사용자 데이터를 사용하지 않는다.

## Scope

- PostgreSQL 17, Auth, API, Edge Runtime만 local stack에서 활성화
- `profiles`, `households`, `household_members`, `user_active_households`
- 활성 성인 역할 `owner`, `admin`, `member`
- primary household 성인 2인과 cross-household isolation용 synthetic fixture
- default-deny RLS, 직접 household/member mutation 차단, removed member의 stale active-selection 차단
- PostgreSQL timezone catalog 기반 IANA timezone 검증
- household당 정확히 한 active Owner와 `owner_member_id` 일치를 보장하는 deferred constraint trigger
- Owner/Admin/Member/removed/other-household actor용 authorization helper와 pgTAP 공격 회귀 테스트
- 인증·DB·개인정보에 의존하지 않는 `health` Edge Function

## Run and verify

저장소 루트에서 Docker를 실행한 뒤 다음을 사용한다.

```bash
npm ci
npx supabase start
npm run supabase:reset
npm run supabase:test
npx supabase db lint --schema public,app_private --level error --fail-on error
npm run supabase:health
npm run supabase:flutter-health
```

`supabase:flutter-health`는 실행 중인 stack의 local URL과 publishable key만 메모리에서 읽는다. service role key, DB URL, JWT secret은 앱·설정·로그에 넣지 않는다.

Supabase CLI가 알리는 local 기본 키와 포트는 production 보안 설정이 아니다. stack은 개발 머신의 Docker networking에 노출될 수 있으므로 신뢰할 수 없는 네트워크에서 실행하지 않는다. Google OAuth와 remote `link`/`push`는 후속 범위다.
