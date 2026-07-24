# Runtime Contracts

구현에서 직접 읽는 기계 판독 계약을 둔다. Markdown 원본은 `docs/contracts/`에 보존되어 있으며, 승인된 Work Package에서 필요한 계약만 materialize한다.

- `toolchain.json`: Flutter/Dart, Android, 환경과 identifier 기준
- `architecture-rules.yaml`: Flutter feature layer 의존 방향과 금지 import 기준
- `supabase-health.schema.json`: local Edge Function health response의 exact JSON 계약
- `client-public-config.schema.json`: client bundle에 허용하는 공개 설정 key의 exact allowlist

DB/API/domain 계약은 해당 Work Package에서 Markdown 원본과 일치하도록 materialize하고 검증한다.
