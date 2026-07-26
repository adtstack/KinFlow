#!/usr/bin/env bash

set -euo pipefail

export CI="${CI:-true}"
export DART_SUPPRESS_ANALYTICS=true
export FLUTTER_SUPPRESS_ANALYTICS=true

kinflow_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kinflow_app_root="$kinflow_repo_root/apps/kinflow_app"
kinflow_report_dir="${KINFLOW_CI_REPORT_DIR:-$kinflow_repo_root/ci-reports/quality}"
kinflow_flutter_bin="${KINFLOW_FLUTTER_BIN:-flutter}"

resolve_dart_bin() {
  if [[ -n "${KINFLOW_DART_BIN:-}" ]]; then
    printf '%s' "$KINFLOW_DART_BIN"
    return
  fi

  local flutter_path
  flutter_path="$(command -v "$kinflow_flutter_bin" 2>/dev/null || true)"
  if [[ -z "$flutter_path" ]]; then
    flutter_path="$kinflow_flutter_bin"
  fi
  local sibling_dart
  sibling_dart="$(dirname "$flutter_path")/dart"
  if [[ -x "$sibling_dart" ]]; then
    printf '%s' "$sibling_dart"
    return
  fi
  command -v dart
}

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

kinflow_dart_bin="$(resolve_dart_bin)"
mkdir -p "$kinflow_report_dir"

kinflow_flutter_version="$($kinflow_flutter_bin --version)"
printf '%s\n' "$kinflow_flutter_version" | grep -F 'Flutter 3.44.7' >/dev/null
printf '%s\n' "$kinflow_flutter_version" | grep -F 'Dart 3.12.2' >/dev/null

{
  printf '%s\n' "$kinflow_flutter_version"
  printf 'node=%s\n' "$(node --version)"
  printf 'pubspec_lock_sha256=%s\n' "$(sha256_file "$kinflow_app_root/pubspec.lock")"
  printf 'package_lock_sha256=%s\n' "$(sha256_file "$kinflow_repo_root/package-lock.json")"
  printf 'toolchain_contract_sha256=%s\n' "$(sha256_file "$kinflow_repo_root/contracts/toolchain.json")"
} >"$kinflow_report_dir/toolchain.txt"

cd "$kinflow_repo_root"
npm run ci:test
npm run ci:workflow
scripts/ci/actionlint.sh

cd "$kinflow_app_root"
flutter_pub_get
"$kinflow_dart_bin" format --output=none --set-exit-if-changed lib test tool
"$kinflow_flutter_bin" analyze --no-pub --fatal-infos --fatal-warnings
"$kinflow_flutter_bin" test \
  --no-pub \
  --coverage \
  --coverage-path "$kinflow_report_dir/lcov.info" \
  --file-reporter "expanded:$kinflow_report_dir/flutter-test.txt"
"$kinflow_dart_bin" run tool/validate_public_config.dart
"$kinflow_dart_bin" run tool/scan_secrets.dart
"$kinflow_dart_bin" run tool/verify_codegen.dart

cd "$kinflow_repo_root"
node scripts/ci/coverage-summary.mjs \
  "$kinflow_report_dir/lcov.info" \
  "$kinflow_report_dir/coverage-summary.json"
printf '%s\n' 'result=PASS' >"$kinflow_report_dir/result.txt"
printf '%s\n' 'Flutter quality gate passed.'
