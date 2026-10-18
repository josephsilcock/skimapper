# Shared helpers for the tools/ scripts. Source, don't execute.
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$TOOLS_DIR/.." && pwd)"
APP_DIR="$REPO_DIR/app"
ANDROID_SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$ANDROID_SDK/platform-tools/adb"
PATROL="${PATROL:-$HOME/.pub-cache/bin/patrol}"

# shellcheck source=../dev.env
source "$TOOLS_DIR/dev.env"

fail() {
  echo "error: $*" >&2
  exit 1
}

# Android builds use the dev config's JDK, not whatever JAVA_HOME the shell happens to hold.
use_android_jdk() {
  JAVA_HOME="$(/usr/libexec/java_home -v "$ANDROID_JDK_VERSION")"
  export JAVA_HOME
}

require_platform() {
  case "${1:-}" in
    ios | android) ;;
    *) fail "platform must be 'ios' or 'android' (got '${1:-}')" ;;
  esac
}
