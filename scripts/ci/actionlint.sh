#!/usr/bin/env bash

set -euo pipefail

kinflow_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kinflow_report_dir="${KINFLOW_CI_REPORT_DIR:-$kinflow_repo_root/ci-reports/quality}"
kinflow_temp_parent="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
kinflow_temp_dir="$(mktemp -d "$kinflow_temp_parent/kinflow-actionlint.XXXXXX")"
kinflow_actionlint_version='1.7.12'

cleanup() {
  case "$kinflow_temp_dir" in
    "$kinflow_temp_parent"/kinflow-actionlint.*) rm -rf -- "$kinflow_temp_dir" ;;
    *) printf 'Refusing to remove unexpected temp path: %s\n' "$kinflow_temp_dir" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)
    kinflow_asset="actionlint_${kinflow_actionlint_version}_linux_amd64.tar.gz"
    kinflow_expected_archive_sha256='8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8'
    kinflow_expected_binary_sha256='c872d6db8c6bf83a8eaa704fc93999f027d55dffbc63b8a6abdccb47df5f4cd4'
    ;;
  Darwin-arm64)
    kinflow_asset="actionlint_${kinflow_actionlint_version}_darwin_arm64.tar.gz"
    kinflow_expected_archive_sha256='aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f'
    kinflow_expected_binary_sha256='8db11704dc296f096216db4db65d86cd7f0ebfdf4c38453a1da276b137b88388'
    ;;
  *)
    printf 'Unsupported actionlint platform: %s-%s\n' "$(uname -s)" "$(uname -m)" >&2
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

if [[ -n "${KINFLOW_ACTIONLINT_BIN:-}" ]]; then
  kinflow_actionlint="$KINFLOW_ACTIONLINT_BIN"
  kinflow_archive_sha256='not-downloaded'
else
  kinflow_archive="$kinflow_temp_dir/$kinflow_asset"
  curl --proto '=https' --tlsv1.2 --fail --location --retry 3 \
    --output "$kinflow_archive" \
    "https://github.com/rhysd/actionlint/releases/download/v$kinflow_actionlint_version/$kinflow_asset"
  kinflow_archive_sha256="$(sha256_file "$kinflow_archive")"
  if [[ "$kinflow_archive_sha256" != "$kinflow_expected_archive_sha256" ]]; then
    printf '%s\n' 'actionlint archive checksum mismatch.' >&2
    exit 1
  fi
  tar -xzf "$kinflow_archive" -C "$kinflow_temp_dir"
  kinflow_actionlint="$kinflow_temp_dir/actionlint"
fi

kinflow_binary_sha256="$(sha256_file "$kinflow_actionlint")"
if [[ "$kinflow_binary_sha256" != "$kinflow_expected_binary_sha256" ]]; then
  printf '%s\n' 'actionlint binary checksum mismatch.' >&2
  exit 1
fi

"$kinflow_actionlint" "$kinflow_repo_root/.github/workflows/ci.yml"
mkdir -p "$kinflow_report_dir"
{
  printf 'actionlint_version=%s\n' "$kinflow_actionlint_version"
  printf 'archive_sha256=%s\n' "$kinflow_archive_sha256"
  printf 'binary_sha256=%s\n' "$kinflow_binary_sha256"
  printf 'result=PASS\n'
} >"$kinflow_report_dir/actionlint.txt"
printf '%s\n' 'GitHub Actions workflow lint passed.'
