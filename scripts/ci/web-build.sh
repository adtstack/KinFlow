#!/usr/bin/env bash

set -euo pipefail

export CI="${CI:-true}"
export DART_SUPPRESS_ANALYTICS=true
export FLUTTER_SUPPRESS_ANALYTICS=true

kinflow_environment="${1:-}"
case "$kinflow_environment" in
  dev)
    kinflow_target='lib/main_dev.dart'
    kinflow_default_config='config/dev.example.json'
    kinflow_application_id='me.newlines.kinflow.dev'
    ;;
  prod)
    kinflow_target='lib/main_prod.dart'
    kinflow_default_config='config/prod.example.json'
    kinflow_application_id='me.newlines.kinflow'
    ;;
  *)
    printf '%s\n' 'Usage: scripts/ci/web-build.sh <dev|prod>' >&2
    exit 64
    ;;
esac

kinflow_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kinflow_app_root="$kinflow_repo_root/apps/kinflow_app"
kinflow_report_dir="${KINFLOW_CI_REPORT_DIR:-$kinflow_repo_root/ci-reports/web/$kinflow_environment}"
kinflow_flutter_bin="${KINFLOW_FLUTTER_BIN:-flutter}"
kinflow_node_bin="${KINFLOW_NODE_BIN:-node}"
kinflow_config="${KINFLOW_PUBLIC_CONFIG:-$kinflow_default_config}"
if [[ "$kinflow_config" != /* ]]; then
  kinflow_config="$kinflow_app_root/$kinflow_config"
fi
if [[ ! -f "$kinflow_config" ]]; then
  printf '%s\n' 'Web public config file does not exist.' >&2
  exit 66
fi

kinflow_output="$kinflow_app_root/build/web"
kinflow_source_commit="$(git -C "$kinflow_repo_root" rev-parse --verify HEAD)"
if [[ ! "$kinflow_source_commit" =~ ^[0-9a-f]{40}$ ]]; then
  printf '%s\n' 'Web source commit is invalid.' >&2
  exit 1
fi
kinflow_source_state='clean'
if [[ -n "$(git -C "$kinflow_repo_root" status --porcelain --untracked-files=normal)" ]]; then
  kinflow_source_state='dirty'
fi

write_failure_report() {
  local command_status="$?"
  trap - EXIT
  if [[ "$command_status" -ne 0 ]]; then
    mkdir -p "$kinflow_report_dir"
    {
      printf 'environment=%s\n' "$kinflow_environment"
      printf 'result=FAIL\n'
      printf 'exit_code=%s\n' "$command_status"
    } >"$kinflow_report_dir/web-$kinflow_environment.txt"
  fi
  exit "$command_status"
}
trap write_failure_report EXIT

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

mkdir -p "$kinflow_report_dir"
cd "$kinflow_app_root"

kinflow_flutter_version="$($kinflow_flutter_bin --version)"
printf '%s\n' "$kinflow_flutter_version" | grep -F 'Flutter 3.44.7' >/dev/null
printf '%s\n' "$kinflow_flutter_version" | grep -F 'Dart 3.12.2' >/dev/null

IFS=$'\t' read -r kinflow_build_name kinflow_build_number < <(
  "$kinflow_node_bin" "$kinflow_repo_root/scripts/ci/web-public-config.mjs" \
    "$kinflow_config" "$kinflow_environment" "$kinflow_application_id"
)
flutter_pub_get
"$kinflow_flutter_bin" build web \
  --release \
  --no-pub \
  --no-wasm-dry-run \
  --pwa-strategy none \
  --build-name "$kinflow_build_name" \
  --build-number "$kinflow_build_number" \
  --target "$kinflow_target" \
  --dart-define-from-file "$kinflow_config"

for kinflow_required_file in \
  index.html \
  flutter.js \
  flutter_bootstrap.js \
  main.dart.js \
  version.json; do
  if [[ ! -s "$kinflow_output/$kinflow_required_file" ]]; then
    printf 'Web build output is missing: %s\n' "$kinflow_required_file" >&2
    exit 1
  fi
done

if [[ -e "$kinflow_output/manifest.json" ]]; then
  printf '%s\n' 'Web Companion must not emit a PWA install manifest.' >&2
  exit 1
fi
if [[ ! -f "$kinflow_output/flutter_service_worker.js" ]] \
  || [[ -s "$kinflow_output/flutter_service_worker.js" ]]; then
  printf '%s\n' 'Web Companion service worker must remain disabled.' >&2
  exit 1
fi
if grep -F '_flutter.loader.load({' "$kinflow_output/flutter_bootstrap.js" \
  >/dev/null; then
  printf '%s\n' 'Web bootstrap must not register a Flutter service worker.' >&2
  exit 1
fi
grep -F '_flutter.loader.load();' "$kinflow_output/flutter_bootstrap.js" \
  >/dev/null
grep -F '<base href="/">' "$kinflow_output/index.html" >/dev/null
grep -F 'name="referrer" content="no-referrer"' \
  "$kinflow_output/index.html" >/dev/null
grep -F 'name="robots" content="noindex, nofollow, noarchive"' \
  "$kinflow_output/index.html" >/dev/null
grep -F '"package_name":"kinflow_app"' "$kinflow_output/version.json" \
  >/dev/null
grep -F "\"version\":\"$kinflow_build_name\"" \
  "$kinflow_output/version.json" >/dev/null
grep -F "\"build_number\":\"$kinflow_build_number\"" \
  "$kinflow_output/version.json" >/dev/null

kinflow_main_sha256="$(sha256_file "$kinflow_output/main.dart.js")"
kinflow_main_bytes="$(wc -c <"$kinflow_output/main.dart.js" | tr -d ' ')"
{
  printf 'environment=%s\n' "$kinflow_environment"
  printf 'target=%s\n' "$kinflow_target"
  printf 'runtime_package=kinflow_app\n'
  printf 'runtime_version=%s+%s\n' \
    "$kinflow_build_name" "$kinflow_build_number"
  printf 'source_commit=%s\n' "$kinflow_source_commit"
  printf 'source_state=%s\n' "$kinflow_source_state"
  printf 'path_url_strategy=enabled\n'
  printf 'pwa_install_manifest=absent\n'
  printf 'service_worker=disabled\n'
  printf 'persistent_api_cache=disabled\n'
  printf 'main_bytes=%s\n' "$kinflow_main_bytes"
  printf 'main_sha256=%s\n' "$kinflow_main_sha256"
  printf 'result=PASS\n'
} >"$kinflow_report_dir/web-$kinflow_environment.txt"
printf '%s  %s\n' "$kinflow_main_sha256" 'main.dart.js' \
  >"$kinflow_report_dir/web-$kinflow_environment.sha256"

trap - EXIT
printf 'Web %s build gate passed: %s bytes, SHA-256 %s.\n' \
  "$kinflow_environment" "$kinflow_main_bytes" "$kinflow_main_sha256"
