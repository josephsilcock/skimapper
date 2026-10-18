# Runs the local endpoint (wrangler dev over Miniflare R2). Source, don't execute.

ENDPOINT_DIR="$REPO_DIR/endpoint"
ENDPOINT_URL="http://127.0.0.1:$ENDPOINT_PORT"
export WRANGLER_SEND_METRICS=false
ENDPOINT_PID=""

seed_endpoint_message() {
  local persist_to="$1" message="$2"
  (cd "$ENDPOINT_DIR" && node scripts/seed-local.ts --persist-to "$persist_to" --message "$message") \
    || fail "could not seed the local endpoint"
}

start_endpoint() {
  local persist_to="$1" log="$2"
  mkdir -p "$(dirname "$log")"
  (cd "$ENDPOINT_DIR" && exec npx wrangler dev --ip 127.0.0.1 --port "$ENDPOINT_PORT" --persist-to "$persist_to") \
    >"$log" 2>&1 &
  ENDPOINT_PID=$!
  for _ in $(seq 1 60); do
    curl -s -o /dev/null "$ENDPOINT_URL/" && return
    kill -0 "$ENDPOINT_PID" 2>/dev/null || fail "local endpoint exited during start-up (see $log)"
    sleep 0.5
  done
  fail "local endpoint did not start on $ENDPOINT_URL (see $log)"
}

stop_endpoint() {
  [[ -n "$ENDPOINT_PID" ]] || return 0
  pkill -P "$ENDPOINT_PID" 2>/dev/null || true
  kill "$ENDPOINT_PID" 2>/dev/null || true
  wait "$ENDPOINT_PID" 2>/dev/null || true
  ENDPOINT_PID=""
}

ensure_port_free() {
  ! curl -s -o /dev/null "$ENDPOINT_URL/" \
    || fail "something is already listening on $ENDPOINT_URL — stop it (a dev-app endpoint?) before running E2E"
}

# Android reaches the host's endpoint through the emulator's own localhost.
forward_endpoint_port() {
  local platform="$1" device="$2"
  [[ "$platform" == android ]] || return 0
  "$ADB" -s "$device" reverse "tcp:$ENDPOINT_PORT" "tcp:$ENDPOINT_PORT" >/dev/null
}

# The --dart-define flags that point an app build at the local endpoint.
endpoint_dart_defines() {
  echo --dart-define "ENDPOINT_URL=$ENDPOINT_URL" --dart-define "ENDPOINT_TIMEOUT_MS=$ENDPOINT_TIMEOUT_MS"
}
