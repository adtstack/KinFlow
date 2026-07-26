#!/usr/bin/env bash

set -euo pipefail

export CI="${CI:-true}"
export DART_SUPPRESS_ANALYTICS=true
export FLUTTER_SUPPRESS_ANALYTICS=true

kinflow_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kinflow_app_root="$kinflow_repo_root/apps/kinflow_app"
kinflow_report_dir="${KINFLOW_CI_REPORT_DIR:-$kinflow_repo_root/ci-reports/backend}"
kinflow_flutter_bin="${KINFLOW_FLUTTER_BIN:-flutter}"
kinflow_started_stack=0

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

flutter_pub_get() {
  local arguments=(pub get --enforce-lockfile)
  if [[ "${KINFLOW_PUB_OFFLINE:-0}" == '1' ]]; then
    arguments+=(--offline)
  fi
  "$kinflow_flutter_bin" "${arguments[@]}"
}

cleanup() {
  local command_status="$?"
  trap - EXIT INT TERM
  if [[ "$kinflow_started_stack" -eq 1 ]]; then
    (cd "$kinflow_repo_root" && npx supabase stop >/dev/null 2>&1) || true
  fi
  if [[ "$command_status" -eq 0 ]]; then
    printf '%s\n' 'result=PASS' >>"$kinflow_report_dir/backend-summary.txt"
  else
    printf '%s\n' 'result=FAIL' >>"$kinflow_report_dir/backend-summary.txt"
  fi
  exit "$command_status"
}

mkdir -p "$kinflow_report_dir"
trap cleanup EXIT INT TERM

cd "$kinflow_repo_root"
npm ci --ignore-scripts --no-audit --no-fund

kinflow_flutter_version="$($kinflow_flutter_bin --version)"
printf '%s\n' "$kinflow_flutter_version" | grep -F 'Flutter 3.44.7' >/dev/null
printf '%s\n' "$kinflow_flutter_version" | grep -F 'Dart 3.12.2' >/dev/null

{
  printf 'node=%s\n' "$(node --version)"
  printf 'npm=%s\n' "$(npm --version)"
  printf 'supabase=%s\n' "$(npx supabase --version)"
  printf 'docker=%s\n' "$(docker --version)"
  kinflow_migration_count=0
  for kinflow_migration in "$kinflow_repo_root"/supabase/migrations/*.sql; do
    if [[ ! -f "$kinflow_migration" ]]; then
      printf '%s\n' 'No Supabase migration files found.' >&2
      exit 1
    fi
    printf 'migration_sha256[%s]=%s\n' \
      "$(basename "$kinflow_migration")" \
      "$(sha256_file "$kinflow_migration")"
    kinflow_migration_count=$((kinflow_migration_count + 1))
  done
  printf 'migration_count=%s\n' "$kinflow_migration_count"
} >"$kinflow_report_dir/backend-summary.txt"

cd "$kinflow_app_root"
flutter_pub_get

cd "$kinflow_repo_root"
if ! npx supabase status >/dev/null 2>&1; then
  npx supabase start >/dev/null
  kinflow_started_stack=1
fi

npm run supabase:reset
printf '%s\n' 'db_reset=PASS' >>"$kinflow_report_dir/backend-summary.txt"
npx supabase db lint --local --level warning --fail-on error
printf '%s\n' 'db_lint=PASS' >>"$kinflow_report_dir/backend-summary.txt"
npm run supabase:test
printf '%s\n' 'pgtap_rls=PASS' >>"$kinflow_report_dir/backend-summary.txt"
npm run supabase:health
printf '%s\n' 'edge_contract=PASS' >>"$kinflow_report_dir/backend-summary.txt"
KINFLOW_FLUTTER_BIN="$kinflow_flutter_bin" npm run supabase:flutter-health
printf '%s\n' 'flutter_live_adapter=PASS' >>"$kinflow_report_dir/backend-summary.txt"
printf '%s\n' 'Supabase backend gate passed.'
