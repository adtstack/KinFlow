# 원본 파일 문서화: `matrices/TIME_RECURRENCE_TEST_MATRIX.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/TIME_RECURRENCE_TEST_MATRIX.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `30`

```csv
﻿test_id,scenario,time_zone,local_input,recurrence,expected,unit,db_integration,device_manual,status,evidence,notes
TIME-001,Timed event basic,Asia/Seoul,2026-07-14 09:00,none,UTC instant round-trip; local 09:00,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-002,All-day basic,Asia/Seoul,2026-07-14,none,date unchanged; exclusive end,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-003,Weekly event across DST spring,America/Los_Angeles,2026-03-01 08:00,FREQ=WEEKLY,local 08:00 preserved,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-004,Weekly event across DST fall,America/Los_Angeles,2026-10-25 08:00,FREQ=WEEKLY,local 08:00 preserved,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-005,Nonexistent local time,America/Los_Angeles,DST spring 02:30,once/recurring,approved deterministic rule/error,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-006,Ambiguous local time,America/Los_Angeles,DST fall 01:30,once/recurring,approved fold selection retained,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-007,Berlin DST spring,Europe/Berlin,02:30 boundary,weekly,deterministic,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-008,Lord Howe 30m DST,Australia/Lord_Howe,boundary,weekly,local intent preserved,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-009,Monthly Jan 31,UTC,2026-01-31,FREQ=MONTHLY,approved last-day/skip policy,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-010,Leap day yearly,UTC,2024-02-29,yearly if supported,approved policy,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-011,All-day timezone change,Pacific/Auckland→America/Los_Angeles,2026-01-01,none,date remains Jan 1,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-012,Event timezone vs household timezone,Tokyo event/Seoul household,23:30,none,Today overlap correct,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-013,Multi-day timed crossing household midnight,UTC event/Seoul household,range,none,appears on all intersecting days,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-014,End date exclusive all-day,UTC,Jul 14→Jul 16 exclusive,none,shows Jul 14-15 only,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-015,Series materializer replay,UTC,daily,daily,no duplicate occurrence,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-016,This occurrence exception,Asia/Seoul,weekly one moved,weekly,only one occurrence changes,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-017,Cancel one occurrence,Asia/Seoul,weekly one cancel,weekly,series continues,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-018,Entire series update,America/Los_Angeles,08:00→09:00,weekly,past preserved; future 09:00,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-019,Exception survives series regeneration,America/Los_Angeles,one custom,weekly,exception preserved,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-020,Household timezone change,Seoul→LA,Today boundary,none,warning/policy; no silent event mutation,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-021,User device timezone travel,Seoul device→London,event fixed timezone,none,event intent unchanged,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-022,Quiet hours spring gap,America/Los_Angeles,02:00-03:00,none,approved delay/skip rule,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-023,Quiet hours fall fold,America/Los_Angeles,01:00-02:00,none,no duplicate notification,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-024,Notification after event edit,Asia/Seoul,start changed,none,old intent cancelled/new deduped,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-025,Chore due no time,Asia/Seoul,local date only,daily,Today correct; reminder policy explicit,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-026,Weekly locale week start,en-US vs ko-KR,calendar grid,weekly,locale display only; recurrence unchanged,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-027,Year boundary,Pacific/Auckland,Dec 31→Jan 1,daily,correct local date/key,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-028,Materialization horizon extension,UTC,range beyond horizon,daily,idempotent expansion,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-029,Unsupported RRULE import/data,UTC,complex rule,unsupported,"safe error/read-only, no wrong expansion",YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
TIME-030,Clock skew client,UTC,client ±1 day,none,server time/expected version prevents corruption,YES,YES if materialized,YES for OS/display/push,NOT_STARTED,,
```
