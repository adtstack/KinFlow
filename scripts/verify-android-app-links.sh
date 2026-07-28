#!/usr/bin/env bash

set -euo pipefail

kinflow_flavor="${1:-}"
kinflow_apk="${2:-}"
kinflow_asset_links="${3:-}"
kinflow_live_host="${4:-}"
if [[ "$#" -gt 4 ]]; then
  printf '%s\n' 'Usage: scripts/verify-android-app-links.sh <dev|prod> <apk> <assetlinks.json> [live-host]' >&2
  exit 64
fi
case "$kinflow_flavor" in
  dev)
    kinflow_expected_package='me.newlines.kinflow.dev'
    ;;
  prod)
    kinflow_expected_package='me.newlines.kinflow'
    ;;
  *)
    printf '%s\n' 'Usage: scripts/verify-android-app-links.sh <dev|prod> <apk> <assetlinks.json> [live-host]' >&2
    exit 64
    ;;
esac

if [[ ! -f "$kinflow_apk" ]]; then
  printf '%s\n' 'Android APK file does not exist.' >&2
  exit 66
fi
if [[ ! -f "$kinflow_asset_links" ]]; then
  printf '%s\n' 'Android asset links file does not exist.' >&2
  exit 66
fi

kinflow_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kinflow_node_bin="${KINFLOW_NODE_BIN:-node}"

resolve_android_build_tool() {
  local tool_name="$1"
  local environment_override="$2"
  if [[ -n "$environment_override" && -x "$environment_override" ]]; then
    printf '%s' "$environment_override"
    return
  fi
  if command -v "$tool_name" >/dev/null 2>&1; then
    command -v "$tool_name"
    return
  fi

  local sdk_root
  local candidate
  for sdk_root in \
    "${ANDROID_HOME:-}" \
    "${ANDROID_SDK_ROOT:-}" \
    "$HOME/Android/Sdk" \
    "$HOME/Library/Android/sdk"; do
    if [[ -z "$sdk_root" || ! -d "$sdk_root/build-tools" ]]; then
      continue
    fi
    candidate="$(find "$sdk_root/build-tools" -type f -name "$tool_name" -print | sort | tail -1)"
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return
    fi
  done
  printf 'Android %s executable was not found.\n' "$tool_name" >&2
  return 1
}

kinflow_aapt_bin="$(
  resolve_android_build_tool aapt "${KINFLOW_AAPT_BIN:-}"
)"
kinflow_apksigner_bin="$(
  resolve_android_build_tool apksigner "${KINFLOW_APKSIGNER_BIN:-}"
)"

kinflow_badging="$($kinflow_aapt_bin dump badging "$kinflow_apk")"
if ! printf '%s\n' "$kinflow_badging" \
  | grep -F "package: name='$kinflow_expected_package'" >/dev/null; then
  printf '%s\n' 'Android APK package does not match the selected environment.' >&2
  exit 1
fi
if [[ "$kinflow_flavor" == 'prod' ]] && \
  printf '%s\n' "$kinflow_badging" | grep -F 'application-debuggable' >/dev/null; then
  printf '%s\n' 'Production asset links cannot be verified from a debuggable APK.' >&2
  exit 1
fi

kinflow_certificates="$($kinflow_apksigner_bin verify --print-certs "$kinflow_apk")"
kinflow_signer_count="$(
  printf '%s\n' "$kinflow_certificates" \
    | grep -Ec '^Signer #[0-9]+ certificate SHA-256 digest:' || true
)"
if [[ "$kinflow_signer_count" != '1' ]]; then
  printf '%s\n' 'Android APK must expose exactly one current signing certificate.' >&2
  exit 1
fi
kinflow_sha256_hex="$(
  printf '%s\n' "$kinflow_certificates" \
    | sed -n 's/^Signer #[0-9][0-9]* certificate SHA-256 digest: //p'
)"
if [[ ! "$kinflow_sha256_hex" =~ ^[0-9a-fA-F]{64}$ ]]; then
  printf '%s\n' 'Android APK SHA-256 signing fingerprint is invalid.' >&2
  exit 1
fi
kinflow_sha256_fingerprint="$(
  printf '%s' "$kinflow_sha256_hex" \
    | tr '[:lower:]' '[:upper:]' \
    | sed 's/../&:/g; s/:$//'
)"

"$kinflow_node_bin" "$kinflow_repo_root/scripts/ci/android-asset-links.mjs" \
  "$kinflow_asset_links" \
  "$kinflow_expected_package" \
  "$kinflow_sha256_fingerprint"
printf 'Android %s APK-to-asset-links verification passed.\n' "$kinflow_flavor"

if [[ -n "$kinflow_live_host" ]]; then
  "$kinflow_node_bin" "$kinflow_repo_root/scripts/ci/android-live-asset-links.mjs" \
    "$kinflow_live_host" \
    "$kinflow_expected_package" \
    "$kinflow_sha256_fingerprint"
fi
