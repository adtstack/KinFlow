#!/usr/bin/env bash

set -euo pipefail

kinflow_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kinflow_flutter_bin="${KINFLOW_FLUTTER_BIN:-flutter}"
kinflow_status="$(cd "$kinflow_repo_root" && npx supabase status -o env 2>/dev/null)"

read_status_value() {
  local key="$1"
  local value
  value="$(printf '%s\n' "$kinflow_status" | awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }')"
  value="${value#\"}"
  value="${value%\"}"
  printf '%s' "$value"
}

kinflow_supabase_url="$(read_status_value API_URL)"
kinflow_supabase_key="$(read_status_value PUBLISHABLE_KEY)"

if [[ -z "$kinflow_supabase_url" || -z "$kinflow_supabase_key" ]]; then
  printf '%s\n' 'Local Supabase URL or publishable key is unavailable.' >&2
  exit 1
fi

cd "$kinflow_repo_root/apps/kinflow_app"
"$kinflow_flutter_bin" test \
  --no-pub \
  test/infrastructure/supabase_connectivity_live_test.dart \
  --dart-define="KINFLOW_LOCAL_SUPABASE_URL=$kinflow_supabase_url" \
  --dart-define="KINFLOW_LOCAL_SUPABASE_PUBLISHABLE_KEY=$kinflow_supabase_key"
