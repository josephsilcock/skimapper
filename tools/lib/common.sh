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

# Android builds use the dev config's JDK. macOS finds it by version, not whatever JAVA_HOME the shell
# happens to hold; elsewhere (a CI runner) JAVA_HOME is trusted but must be that version.
use_android_jdk() {
  if [[ "$(uname -s)" == Darwin ]]; then select_macos_jdk; else require_given_jdk; fi
}

select_macos_jdk() {
  JAVA_HOME="$(/usr/libexec/java_home -v "$ANDROID_JDK_VERSION")"
  export JAVA_HOME
}

require_given_jdk() {
  [[ -n "${JAVA_HOME:-}" ]] || fail "JAVA_HOME is not set; Android builds need JDK $ANDROID_JDK_VERSION (tools/dev.env ANDROID_JDK_VERSION)"
  local major
  major="$("$JAVA_HOME/bin/java" -version 2>&1 | sed -nE '1s/.*version "([0-9]+).*/\1/p')"
  [[ "$major" == "$ANDROID_JDK_VERSION" ]] \
    || fail "JAVA_HOME ($JAVA_HOME) is JDK $major; tools/dev.env ANDROID_JDK_VERSION is $ANDROID_JDK_VERSION"
}

require_platform() {
  case "${1:-}" in
    ios | android) ;;
    *) fail "platform must be 'ios' or 'android' (got '${1:-}')" ;;
  esac
}
