# Phase 00 Technical PoC

이 디렉터리는 production architecture가 아니라 Phase 00의 위험 검증용이다. 여기의 schema나 test data를 production migration으로 복사하지 않는다.

## RLS household isolation

`rls_household_isolation.sql`은 PostgreSQL 16에서 다음 최소 계약을 검증한다.

- 활성 household member는 자기 household만 조회한다.
- 다른 household row는 조회 결과에 나타나지 않는다.
- 제거된 member는 household를 조회하지 못한다.
- authenticated role의 직접 쓰기는 정책/권한 부재로 거부된다.

실행 예시는 Phase evidence의 `TECHNICAL_POC.md`에 기록한다.

## 비범위

- 전체 `database-schema.sql` 적용
- Supabase Auth JWT 검증
- production RPC와 migration
- Managed Child acting context
- chores/calendar/billing RLS 전체 matrix
