# 원본 파일 문서화: `matrices/PLATFORM_DEFINITION_OF_DONE.csv`

> 이 파일은 **Markdown 전용 문서팩**을 위해 원본 텍스트 파일을 코드 블록으로 보존한 문서입니다.

- 구현 시 생성할 원본 경로: `matrices/PLATFORM_DEFINITION_OF_DONE.csv`
- 원본 형식: `csv`
- 사용 방법: 아래 코드 블록의 내용을 복사하여 위 원본 경로에 저장합니다.
- 데이터 행 수(헤더 제외): `55`

```csv
﻿ID,Platform,Tier,Area,Acceptance_Criteria,Automation,Manual_Evidence,Status
PDOD-001,iPhone,Tier1,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-002,iPhone,Tier1,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-003,iPhone,Tier1,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-004,iPhone,Tier1,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-005,iPhone,Tier1,Notifications,permission/inbox/push or documented fallback/deep link,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-006,iPhone,Tier1,Billing,catalog/entitlement; purchase only where supported,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-007,iPhone,Tier1,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-008,iPhone,Tier1,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-009,iPhone,Tier1,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-010,iPhone,Tier1,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-011,iPhone,Tier1,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-012,iPad,Tier1,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-013,iPad,Tier1,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-014,iPad,Tier1,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-015,iPad,Tier1,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-016,iPad,Tier1,Notifications,permission/inbox/push or documented fallback/deep link,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-017,iPad,Tier1,Billing,catalog/entitlement; purchase only where supported,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-018,iPad,Tier1,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-019,iPad,Tier1,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-020,iPad,Tier1,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-021,iPad,Tier1,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-022,iPad,Tier1,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-023,Android Phone,Tier1,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-024,Android Phone,Tier1,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-025,Android Phone,Tier1,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-026,Android Phone,Tier1,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-027,Android Phone,Tier1,Notifications,permission/inbox/push or documented fallback/deep link,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-028,Android Phone,Tier1,Billing,catalog/entitlement; purchase only where supported,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-029,Android Phone,Tier1,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-030,Android Phone,Tier1,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-031,Android Phone,Tier1,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-032,Android Phone,Tier1,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-033,Android Phone,Tier1,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-034,Android Tablet,Tier1,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-035,Android Tablet,Tier1,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-036,Android Tablet,Tier1,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-037,Android Tablet,Tier1,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-038,Android Tablet,Tier1,Notifications,permission/inbox/push or documented fallback/deep link,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-039,Android Tablet,Tier1,Billing,catalog/entitlement; purchase only where supported,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-040,Android Tablet,Tier1,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-041,Android Tablet,Tier1,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-042,Android Tablet,Tier1,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-043,Android Tablet,Tier1,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-044,Android Tablet,Tier1,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-045,Web Companion,Tier2,Shell/Auth,"launch, callback, restore, logout/account isolation",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-046,Web Companion,Tier2,Household,"adult create, invite, join, roles",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-047,Web Companion,Tier2,Chores/Today,"create, assign, repeat, complete, stale/conflict states",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-048,Web Companion,Tier2,Calendar,timed/all-day/repeat/exception/timezone,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-049,Web Companion,Tier2,Notifications,inbox and email/mobile fallback; Web Push not initial blocker,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-050,Web Companion,Tier2,Billing,server entitlement read; paid web purchase separately gated,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-051,Web Companion,Tier2,Privacy,delete/export/cache purge/support path,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-052,Web Companion,Tier2,Accessibility,"screen reader, large text/zoom, focus/touch/keyboard",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-053,Web Companion,Tier2,Localization,"EN/KO/pseudo, locale/timezone formatting",Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-054,Web Companion,Tier2,Performance,startup/Today/jank/payload budget,Automated where possible,Required before platform Gate,NOT_STARTED
PDOD-055,Web Companion,Tier2,Reliability,resume/reconnect/update/version compatibility,Automated where possible,Required before platform Gate,NOT_STARTED
```
