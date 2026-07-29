#!/usr/bin/env bash

set -euo pipefail

kinflow_flavor="${1:-}"
kinflow_config_input="${2:-}"
case "$kinflow_flavor" in
  dev)
    kinflow_target='lib/main_dev.dart'
    kinflow_package='me.newlines.kinflow.dev'
    ;;
  prod)
    kinflow_target='lib/main_prod.dart'
    kinflow_package='me.newlines.kinflow'
    ;;
  *)
    printf '%s\n' 'Usage: scripts/run-android.sh <dev|prod> <public-config.json> [flutter run arguments...]' >&2
    exit 64
    ;;
esac
if [[ -z "$kinflow_config_input" ]]; then
  printf '%s\n' 'A public config JSON path is required.' >&2
  exit 64
fi

kinflow_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kinflow_app_root="$kinflow_repo_root/apps/kinflow_app"
kinflow_node_bin="${KINFLOW_NODE_BIN:-node}"
kinflow_flutter_bin="${KINFLOW_FLUTTER_BIN:-flutter}"
kinflow_source_commit="$(git -C "$kinflow_repo_root" rev-parse --verify HEAD)"
if [[ ! "$kinflow_source_commit" =~ ^[0-9a-f]{40}$ ]]; then
  printf '%s\n' 'Android source commit is invalid.' >&2
  exit 1
fi
kinflow_source_state='clean'
if [[ -n "$(git -C "$kinflow_repo_root" status --porcelain --untracked-files=normal)" ]]; then
  kinflow_source_state='dirty'
fi

if [[ "$kinflow_config_input" = /* ]]; then
  kinflow_config="$kinflow_config_input"
elif [[ -f "$kinflow_config_input" ]]; then
  kinflow_config="$(cd "$(dirname "$kinflow_config_input")" && pwd)/$(basename "$kinflow_config_input")"
else
  kinflow_config="$kinflow_app_root/$kinflow_config_input"
fi
if [[ ! -f "$kinflow_config" ]]; then
  printf '%s\n' 'The public config JSON file does not exist.' >&2
  exit 66
fi

kinflow_auth_redirect_host="$(
  "$kinflow_node_bin" "$kinflow_repo_root/scripts/ci/android-public-config.mjs" \
    "$kinflow_config" "$kinflow_flavor" "$kinflow_package"
)"

cd "$kinflow_app_root"
exec "$kinflow_flutter_bin" run \
  --flavor "$kinflow_flavor" \
  --target "$kinflow_target" \
  --dart-define-from-file "$kinflow_config" \
  --android-project-arg "kinflowAuthRedirectHost=$kinflow_auth_redirect_host" \
  --android-project-arg "kinflowSourceCommit=$kinflow_source_commit" \
  --android-project-arg "kinflowSourceState=$kinflow_source_state" \
  "${@:3}"
