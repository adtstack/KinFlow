# KinFlow Mobile Release Audit Prompt

Store RC를 제출하기 전에 문서와 evidence를 감사하라.

확인 범위:

- accepted/open decision과 launch blocker
- signed iOS IPA/Android AAB provenance
- current Apple/Google SDK·target·billing·privacy 정책
- full RLS authorization matrix
- billing lifecycle matrix와 sandbox evidence
- recurrence/timezone matrix
- push foreground/background/terminated 실제 기기
- account deletion/export/public request path
- Managed Child와 parental gate
- accessibility EN/KO actual device journey
- migration/backup/restore/rollback
- SLO dashboard/alerts/support/runbook
- blocker/critical defect와 risk acceptance

결과를 다음으로 분류한다.

- `GO`
- `GO WITH EXPLICIT RISK ACCEPTANCE`
- `NO-GO`

NO-GO 항목은 왜 사용자/보안/정책에 영향을 주는지, 해제에 필요한 evidence를 적는다. 문서에 있다고 실행된 것으로 간주하지 않는다.
