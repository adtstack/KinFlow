#!/usr/bin/env bash

set -euo pipefail

kinflow_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kinflow_report_dir="${KINFLOW_CI_REPORT_DIR:-$kinflow_repo_root/ci-reports/dependency}"
kinflow_temp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
kinflow_temp_dir="$(mktemp -d "$kinflow_temp_parent/kinflow-osv.XXXXXX")"
kinflow_scanner_version='2.3.8'

cleanup() {
  case "$kinflow_temp_dir" in
    "$kinflow_temp_parent"/kinflow-osv.*) rm -rf -- "$kinflow_temp_dir" ;;
    *) printf 'Refusing to remove unexpected temp path: %s\n' "$kinflow_temp_dir" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)
    kinflow_asset='osv-scanner_linux_amd64'
    kinflow_expected_sha256='bc98e15319ed0d515e3f9235287ba53cdc5535d576d24fd573978ecfe9ab92dc'
    ;;
  Darwin-arm64)
    kinflow_asset='osv-scanner_darwin_arm64'
    kinflow_expected_sha256='a8cd6507b06239f463a7642430cfd2d154882f150f6e30cdc0653e28dfc34216'
    ;;
  *)
    printf 'Unsupported OSV-Scanner platform: %s-%s\n' "$(uname -s)" "$(uname -m)" >&2
    exit 1
    ;;
esac

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

kinflow_scanner="${KINFLOW_OSV_SCANNER_BIN:-$kinflow_temp_dir/osv-scanner}"
kinflow_cache="$kinflow_temp_dir/cache"
mkdir -p "$kinflow_cache" "$kinflow_report_dir"
if [[ -z "${KINFLOW_OSV_SCANNER_BIN:-}" ]]; then
  curl --proto '=https' --tlsv1.2 --fail --location --retry 3 \
    --output "$kinflow_scanner" \
    "https://github.com/google/osv-scanner/releases/download/v$kinflow_scanner_version/$kinflow_asset"
fi
kinflow_actual_sha256="$(sha256_file "$kinflow_scanner")"
if [[ "$kinflow_actual_sha256" != "$kinflow_expected_sha256" ]]; then
  printf '%s\n' 'OSV-Scanner binary checksum mismatch.' >&2
  exit 1
fi
chmod +x "$kinflow_scanner"

OSV_SCANNER_LOCAL_DB_CACHE_DIRECTORY="$kinflow_cache" \
  OSV_SCALIBR_LOCAL_DB_CACHE_DIRECTORY="$kinflow_cache" \
  XDG_CACHE_HOME="$kinflow_cache" "$kinflow_scanner" scan source \
  --download-offline-databases \
  --offline-vulnerabilities \
  --data-source native \
  --no-resolve \
  --format json \
  --output-file "$kinflow_temp_dir/public-seed-report.json" \
  --lockfile "$kinflow_repo_root/scripts/ci/fixtures/osv/package-lock.json" \
  --lockfile "$kinflow_repo_root/scripts/ci/fixtures/osv/pubspec.lock"

OSV_SCANNER_LOCAL_DB_CACHE_DIRECTORY="$kinflow_cache" \
  OSV_SCALIBR_LOCAL_DB_CACHE_DIRECTORY="$kinflow_cache" \
  XDG_CACHE_HOME="$kinflow_cache" "$kinflow_scanner" scan source \
  --offline \
  --offline-vulnerabilities \
  --data-source native \
  --no-resolve \
  --all-packages \
  --format json \
  --output-file "$kinflow_report_dir/osv-report.json" \
  --lockfile "$kinflow_repo_root/package-lock.json" \
  --lockfile "$kinflow_repo_root/apps/kinflow_app/pubspec.lock"

{
  printf 'scanner_version=%s\n' "$kinflow_scanner_version"
  printf 'scanner_sha256=%s\n' "$kinflow_actual_sha256"
  printf 'database_files=%s\n' "$(find "$kinflow_cache" -type f | wc -l | tr -d ' ')"
  printf 'actual_scan_network=disabled\n'
  printf 'data_source=native\n'
  printf 'dependency_resolution=lockfile-only\n'
  printf 'result=PASS\n'
} >"$kinflow_report_dir/osv-metadata.txt"
printf '%s\n' 'Offline OSV vulnerability scan passed.'
