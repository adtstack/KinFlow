# 16. 운영, 지원, 장애 대응 Runbook

- 상태: ACCEPTED

## 1. 운영 소유권

각 production subsystem은 owner, backup owner, dashboard, alert, runbook을 갖는다.

- Auth/Household/RLS
- Chores/Calendar/Recurrence
- Notifications
- Billing/Entitlement
- Privacy deletion/export
- Mobile release
- Web Companion

## 2. 장애 등급

| 등급 | 예시 | 대응 |
|---|---|---|
| SEV-0 | household 간 데이터 노출, signing/secret compromise | 즉시 차단, incident commander, legal/privacy escalation |
| SEV-1 | 로그인/Today/결제 광범위 장애, 데이터 손상 | rollout 중단, 24/7 대응 |
| SEV-2 | 일부 기능/국가/플랫폼 장애 | owner 대응, workaround |
| SEV-3 | 경미한 defect/성능 저하 | backlog와 예정 수정 |

## 3. 초기 대응

1. incident ID와 commander 지정
2. 사용자 영향과 시작 시점 확인
3. rollout/worker/webhook/feature flag 변경 여부 확인
4. 증거 보존, 민감 log 공유 제한
5. 안전한 완화 실행
6. 상태 업데이트 cadence 결정
7. 복구 후 데이터 정합성 검증

## 4. 주요 Runbook

### Auth 장애

- Supabase status와 token refresh error 확인
- destructive mutation 일시 차단
- stale session 데이터를 안전하게 잠금
- status 안내와 retry backoff

### RLS/데이터 노출 의심

- 관련 endpoint/table 즉시 disable 또는 deny-all policy
- service role job 정지
- audit/request ID 보존
- 영향 household 범위 계산
- legal/privacy process 시작

### Recurrence job 지연

- queue depth/lease/dead letter
- materialization horizon 확인
- idempotent backfill
- 알림 stale suppression
- 사용자 Today fallback

### Notification 폭주

- worker kill switch
- dedupe key 검증
- pending job quarantine
- provider throttle
- 이미 발송된 잘못된 메시지 대응

### Billing mismatch

- purchase UI를 무조건 닫지 않고 pending 상태 안내
- webhook lag/provider status
- authoritative customer refresh
- entitlement recompute
- 중복 결제 방지
- manual remediation audit

### 삭제/내보내기 지연

- job state와 blocked dependency 확인
- download URL invalidation
- 법적 SLA와 사용자 안내
- retry/manual completion audit

## 5. 백업과 복구

- production backup schedule/retention 문서화
- 정기 restore drill을 별도 isolated project에서 수행
- RPO/RTO 목표 승인
- restore 후 RLS, membership, recurrence, entitlement 정합성 검사
- migration 전에 restore point와 recovery procedure 확인

## 6. 고객 지원 도구

운영자 도구는 기본적으로 read-only이며 다음 원칙을 따른다.

- support identity와 이유 기록
- 최소 household metadata
- raw content와 child data 최소 노출
- entitlement refresh 같은 action은 승인과 감사 기록
- 사용자를 가장하거나 RLS를 우회하는 일반 UI 금지

## 7. Post-incident

5영업일 이내 또는 심각도에 맞춰:

- timeline
- root cause와 contributing factors
- 탐지/완화 지연
- 사용자 영향
- 데이터 정합성 결과
- corrective action, owner, due date
- runbook/test/alert 문서 갱신

비난보다 시스템 개선을 우선하되 보안·개인정보 책임은 명확히 한다.
