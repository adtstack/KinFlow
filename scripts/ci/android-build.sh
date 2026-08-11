#!/usr/bin/env bash

set -euo pipefail

export CI="${CI:-true}"
export DART_SUPPRESS_ANALYTICS=true
export FLUTTER_SUPPRESS_ANALYTICS=true

kinflow_flavor="${1:-}"
case "$kinflow_flavor" in
  dev)
    kinflow_target='lib/main_dev.dart'
    kinflow_default_config='config/dev.example.json'
    kinflow_package='me.newlines.kinflow.dev'
    kinflow_label='KinFlow Dev'
    ;;
  prod)
    kinflow_target='lib/main_prod.dart'
    kinflow_default_config='config/prod.example.json'
    kinflow_package='me.newlines.kinflow'
    kinflow_label='KinFlow'
    ;;
  *)
    printf '%s\n' 'Usage: scripts/ci/android-build.sh <dev|prod>' >&2
    exit 64
    ;;
esac

kinflow_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
kinflow_app_root="$kinflow_repo_root/apps/kinflow_app"
kinflow_report_dir="${KINFLOW_CI_REPORT_DIR:-$kinflow_repo_root/ci-reports/android/$kinflow_flavor}"
kinflow_flutter_bin="${KINFLOW_FLUTTER_BIN:-flutter}"
kinflow_node_bin="${KINFLOW_NODE_BIN:-node}"
kinflow_source_commit="$(git -C "$kinflow_repo_root" rev-parse --verify HEAD)"
if [[ ! "$kinflow_source_commit" =~ ^[0-9a-f]{40}$ ]]; then
  printf '%s\n' 'Android source commit is invalid.' >&2
  exit 1
fi
kinflow_source_state='clean'
if [[ -n "$(git -C "$kinflow_repo_root" status --porcelain --untracked-files=normal)" ]]; then
  kinflow_source_state='dirty'
fi
kinflow_apk="$kinflow_app_root/build/app/outputs/flutter-apk/app-$kinflow_flavor-debug.apk"
kinflow_config="${KINFLOW_PUBLIC_CONFIG:-$kinflow_default_config}"
if [[ "$kinflow_config" != /* ]]; then
  kinflow_config="$kinflow_app_root/$kinflow_config"
fi
if [[ ! -f "$kinflow_config" ]]; then
  printf '%s\n' 'Android public config file does not exist.' >&2
  exit 66
fi
kinflow_auth_redirect_host="$(
  "$kinflow_node_bin" "$kinflow_repo_root/scripts/ci/android-public-config.mjs" \
    "$kinflow_config" "$kinflow_flavor" "$kinflow_package"
)"

write_failure_report() {
  local command_status="$?"
  trap - EXIT
  if [[ "$command_status" -ne 0 ]]; then
    mkdir -p "$kinflow_report_dir"
    {
      printf 'flavor=%s\n' "$kinflow_flavor"
      printf 'result=FAIL\n'
      printf 'exit_code=%s\n' "$command_status"
    } >"$kinflow_report_dir/android-$kinflow_flavor.txt"
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

resolve_aapt() {
  if [[ -n "${KINFLOW_AAPT_BIN:-}" && -x "$KINFLOW_AAPT_BIN" ]]; then
    printf '%s' "$KINFLOW_AAPT_BIN"
    return
  fi
  if command -v aapt >/dev/null 2>&1; then
    command -v aapt
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
    candidate="$(find "$sdk_root/build-tools" -type f -name aapt -print | sort | tail -1)"
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return
    fi
  done
  printf '%s\n' 'Android aapt executable was not found.' >&2
  return 1
}

mkdir -p "$kinflow_report_dir"
cd "$kinflow_app_root"

kinflow_flutter_version="$($kinflow_flutter_bin --version)"
printf '%s\n' "$kinflow_flutter_version" | grep -F 'Flutter 3.44.7' >/dev/null
printf '%s\n' "$kinflow_flutter_version" | grep -F 'Dart 3.12.2' >/dev/null
flutter_pub_get
"$kinflow_flutter_bin" build apk \
  --debug \
  --no-pub \
  --flavor "$kinflow_flavor" \
  --target "$kinflow_target" \
  --dart-define-from-file "$kinflow_config" \
  --android-project-arg "kinflowAuthRedirectHost=$kinflow_auth_redirect_host" \
  --android-project-arg "kinflowSourceCommit=$kinflow_source_commit" \
  --android-project-arg "kinflowSourceState=$kinflow_source_state"

if [[ ! -f "$kinflow_apk" ]]; then
  printf 'Expected APK is missing: %s\n' "$kinflow_apk" >&2
  exit 1
fi

kinflow_aapt_bin="$(resolve_aapt)"
kinflow_badging="$($kinflow_aapt_bin dump badging "$kinflow_apk")"
printf '%s\n' "$kinflow_badging" | grep -F "package: name='$kinflow_package'" >/dev/null
printf '%s\n' "$kinflow_badging" | grep -F "compileSdkVersion='36'" >/dev/null
printf '%s\n' "$kinflow_badging" | grep -F "sdkVersion:'24'" >/dev/null
printf '%s\n' "$kinflow_badging" | grep -F "targetSdkVersion:'36'" >/dev/null
printf '%s\n' "$kinflow_badging" | grep -F "application-label:'$kinflow_label'" >/dev/null

kinflow_manifest="$($kinflow_aapt_bin dump xmltree "$kinflow_apk" AndroidManifest.xml)"
if ! printf '%s\n' "$kinflow_manifest" \
  | grep -Eq 'A: android:allowBackup\([^)]*\)=\(type 0x12\)0x0'; then
  printf '%s\n' 'APK backup contract changed: android:allowBackup must be false.' >&2
  exit 1
fi
if ! printf '%s\n' "$kinflow_manifest" \
  | grep -E 'A: android:autoVerify\([^)]*\)=\(type 0x12\)0xffffffff' \
    >/dev/null; then
  printf '%s\n' 'APK App Link contract changed: autoVerify must be true.' >&2
  exit 1
fi
for kinflow_app_link_value in \
  'android.intent.action.VIEW' \
  'android.intent.category.DEFAULT' \
  'android.intent.category.BROWSABLE' \
  'https' \
  "$kinflow_auth_redirect_host" \
  '/invite/'; do
  if ! printf '%s\n' "$kinflow_manifest" \
    | grep -F "$kinflow_app_link_value" >/dev/null; then
    printf 'APK App Link contract is missing: %s\n' \
      "$kinflow_app_link_value" >&2
    exit 1
  fi
done
for kinflow_provenance_value in \
  'me.newlines.kinflow.SOURCE_COMMIT' \
  "$kinflow_source_commit" \
  'me.newlines.kinflow.SOURCE_STATE' \
  "$kinflow_source_state"; do
  if ! printf '%s\n' "$kinflow_manifest" \
    | grep -F "$kinflow_provenance_value" >/dev/null; then
    printf '%s\n' 'APK source provenance contract changed.' >&2
    exit 1
  fi
done

kinflow_permissions="$($kinflow_aapt_bin dump permissions "$kinflow_apk")"
kinflow_expected_permissions="$(printf '%s\n' \
  "package: $kinflow_package" \
  "uses-permission: name='android.permission.INTERNET'" \
  "uses-permission: name='com.android.vending.BILLING'" \
  "uses-permission: name='android.permission.POST_NOTIFICATIONS'" \
  "uses-permission: name='android.permission.WAKE_LOCK'" \
  "uses-permission: name='android.permission.ACCESS_NETWORK_STATE'" \
  "uses-permission: name='android.permission.VIBRATE'" \
  "uses-permission: name='android.permission.USE_BIOMETRIC'" \
  "uses-permission: name='android.permission.USE_FINGERPRINT'" \
  "uses-permission: name='com.google.android.c2dm.permission.RECEIVE'" \
  "permission: $kinflow_package.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" \
  "uses-permission: name='$kinflow_package.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'")"
if [[ "$kinflow_permissions" != "$kinflow_expected_permissions" ]]; then
  printf '%s\n' 'APK permission contract changed:' >&2
  printf '%s\n' "$kinflow_permissions" >&2
  exit 1
fi

kinflow_sha256="$(sha256_file "$kinflow_apk")"
kinflow_bytes="$(wc -c <"$kinflow_apk" | tr -d ' ')"
{
  printf 'flavor=%s\n' "$kinflow_flavor"
  printf 'package=%s\n' "$kinflow_package"
  printf 'label=%s\n' "$kinflow_label"
  printf 'min_api=24\n'
  printf 'target_api=36\n'
  printf 'compile_api=36\n'
  printf 'source_commit=%s\n' "$kinflow_source_commit"
  printf 'source_state=%s\n' "$kinflow_source_state"
  printf 'android_backup=disabled\n'
  printf 'app_link=https://%s/invite/*;auto_verify=true\n' "$kinflow_auth_redirect_host"
  printf 'permissions=INTERNET,PLAY_BILLING,POST_NOTIFICATIONS,WAKE_LOCK,ACCESS_NETWORK_STATE,VIBRATE,USE_BIOMETRIC,USE_FINGERPRINT,FCM_RECEIVE,package-scoped-dynamic-receiver\n'
  printf 'bytes=%s\n' "$kinflow_bytes"
  printf 'sha256=%s\n' "$kinflow_sha256"
  printf 'result=PASS\n'
} >"$kinflow_report_dir/android-$kinflow_flavor.txt"
printf '%s  %s\n' "$kinflow_sha256" "$(basename "$kinflow_apk")" \
  >"$kinflow_report_dir/android-$kinflow_flavor.sha256"
trap - EXIT
printf 'Android %s build gate passed: %s bytes, SHA-256 %s.\n' \
  "$kinflow_flavor" "$kinflow_bytes" "$kinflow_sha256"
