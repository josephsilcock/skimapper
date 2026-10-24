# Runs the local endpoint (wrangler dev over Miniflare R2). Source, don't execute.
source "$TOOLS_DIR/lib/run-record.sh"

ENDPOINT_DIR="$REPO_DIR/endpoint"
ENDPOINT_URL="http://127.0.0.1:$ENDPOINT_PORT"
# The route the app reads first (the Worker's documentRoutes; the app's SkeletonMessageLine). Start-up
# waits until it answers, with any status and any body, so its cold first answer isn't the app's.
ENDPOINT_READY_PATH="/v1/skeleton/message"
export WRANGLER_SEND_METRICS=false
ENDPOINT_PID=""

seed_endpoint_message() {
  local persist_to="$1" message="$2"
  (cd "$ENDPOINT_DIR" && node scripts/seed-local.ts --persist-to "$persist_to" --message "$message") \
    || fail "could not seed the local endpoint"
}

seed_endpoint_malformed() {
  local persist_to="$1"
  (cd "$ENDPOINT_DIR" && node scripts/seed-local.ts --persist-to "$persist_to" --malformed) \
    || fail "could not seed the local endpoint"
}

# The endpoint's output goes to stdout, stamped. Process substitution rather than a pipe, so
# ENDPOINT_PID stays the endpoint itself and stop_endpoint stops the right process.
start_endpoint() {
  local persist_to="$1"
  (cd "$ENDPOINT_DIR" && exec npx wrangler dev --ip 127.0.0.1 --port "$ENDPOINT_PORT" --persist-to "$persist_to") \
    > >(stamp_lines endpoint) 2>&1 &
  ENDPOINT_PID=$!
  for _ in $(seq 1 60); do
    curl -s -o /dev/null "$ENDPOINT_URL$ENDPOINT_READY_PATH" \
      && { record_milestone "endpoint answers on $ENDPOINT_URL$ENDPOINT_READY_PATH"; return; }
    kill -0 "$ENDPOINT_PID" 2>/dev/null || fail "local endpoint exited during start-up (see its output)"
    sleep 0.5
  done
  fail "local endpoint did not start on $ENDPOINT_URL (see its output)"
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
