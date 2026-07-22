# Phase 05 — 알림, 작업 큐, 신뢰성, 제한된 동기화

## 목표

집안일·일정 알림을 서버에서 신뢰성 있게 생성하고, 모바일 앱의 foreground/background/terminated 상태에서 안전하게 전달하며 네트워크 단절과 중복을 처리한다.

## Entry

Chores/Calendar domain event와 occurrence 안정화.

## Work Packages

### WP05-01 Outbox/job worker

- event/outbox schema
- lease/retry/dead letter
- idempotent handler
- monitoring/replay

### WP05-02 Notification preferences/inbox

- per-type settings
- quiet hours/timezone
- in-app durable inbox
- read/unread/badge

### WP05-03 Device registration

- installation identity
- FCM token lifecycle
- logout/account switch/removal purge
- invalid token cleanup

### WP05-04 Mobile push

- Firebase/APNs config
- permission pre-prompt
- foreground/local presentation
- background/terminated handler
- deep link tap authz

### WP05-05 Reliability

- provider outage/backoff
- duplicate/out-of-order
- stale suppression
- queue alert/SLO

### WP05-06 Offline/read cache

- stale read cache namespace
- logout/household purge
- one safe chore-completion outbox PoC
- membership/session/version/TTL revalidation

Offline mutation이 위험하거나 가치가 낮으면 read-only cache로 남긴다.

## 자동 검증

- queue lease/crash/retry/dead letter
- notification dedupe/quiet hours
- payload privacy
- token rotation/purge
- deep link parser
- outbox auth binding

## 수동 검증

- iOS/Android actual device permission states
- foreground/background/terminated push
- notification tap after resource delete/membership removal
- provider/network outage
- account switch and cache forensic check

## Exit Gate

inbox는 durable하고 push는 중복 폭주 없이 주요 앱 상태에서 동작한다. 서버 worker가 중요한 알림 시간의 권위다. offline 범위가 명시적으로 승인된다.

## Rollback

push worker kill switch, provider pause, pending job quarantine, local completion outbox feature flag가 존재한다.
