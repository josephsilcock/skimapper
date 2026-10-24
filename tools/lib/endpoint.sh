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

start_endpoint() {
  local persist_to="$1"
  launch_endpoint "$persist_to"
  await_endpoint_answers
}

# The endpoint's output goes to stdout, stamped. The stamper is opened here, before the fork, so it
# stays outside the endpoint's process tree: stop_endpoint leaves it running to record the last lines.
launch_endpoint() {
  local persist_to="$1"
  exec 3> >(stamp_lines endpoint)
  (run_endpoint_server "$persist_to") >&3 2>&1 3>&- &
  ENDPOINT_PID=$!
  exec 3>&-
}

await_endpoint_answers() {
  for _ in $(seq 1 60); do
    curl -s -o /dev/null "$ENDPOINT_URL$ENDPOINT_READY_PATH" \
      && { record_milestone "endpoint answers on $ENDPOINT_URL$ENDPOINT_READY_PATH"; return; }
    kill -0 "$ENDPOINT_PID" 2>/dev/null || fail "local endpoint exited during start-up (see its output)"
    sleep 0.5
  done
  fail "local endpoint did not start on $ENDPOINT_URL (see its output)"
}

run_endpoint_server() {
  local persist_to="$1"
  cd "$ENDPOINT_DIR" && exec npx wrangler dev --ip 127.0.0.1 --port "$ENDPOINT_PORT" --persist-to "$persist_to"
}

stop_endpoint() {
  [[ -n "$ENDPOINT_PID" ]] || return 0
  local endpoint="$ENDPOINT_PID" tree
  # Cleared before anything can fail, so the stop an EXIT trap repeats after a failed one does nothing.
  ENDPOINT_PID=""
  # shellcheck disable=SC2207
  tree=($(process_tree "$endpoint"))
  kill "${tree[@]}" 2>/dev/null || true
  record_milestone "stopping the endpoint: signalled PIDs ${tree[*]}"
  await_endpoint_gone "${tree[@]}"
  wait "$endpoint" 2>/dev/null || true
}

# The process and all its descendants, taken in one pass before any of them is signalled: a parent
# that dies first would otherwise orphan its children out of reach.
process_tree() {
  local pid="$1" child
  echo "$pid"
  for child in $(pgrep -P "$pid" || true); do
    process_tree "$child"
  done
}

await_endpoint_gone() {
  local deadline holders
  deadline=$(( $(now_ms) + ENDPOINT_STOP_TIMEOUT_MS ))
  while true; do
    holders="$(port_holders)"
    any_running "$@" || [[ -n "$holders" ]] || return 0
    (( $(now_ms) < deadline )) || break
    sleep 0.1
  done
  record_port_holders
  fail "the local endpoint did not stop within $ENDPOINT_STOP_TIMEOUT_MS ms; port $ENDPOINT_PORT is held by $(named_holders "$holders")"
}

# bash 3.2 (macOS) has no millisecond clock of its own.
now_ms() {
  node -e 'console.log(Date.now())'
}

# "<command> <pid>" per port holder, comma-separated; lsof's header row dropped.
named_holders() {
  local named
  named="$(awk 'NR > 1 { print $1, $2 }' <<<"$1" | paste -sd, -)"
  echo "${named:-nothing}"
}

# A zombie has exited; it only awaits its parent's wait.
any_running() {
  local pid stat
  for pid in "$@"; do
    stat="$(ps -o stat= -p "$pid" || true)"
    [[ -z "$stat" || "$stat" == Z* ]] || return 0
  done
  return 1
}

# The processes listening on the endpoint port; none means the port is free.
port_holders() {
  command -v lsof >/dev/null || fail "lsof is not installed; it shows who holds the endpoint port"
  lsof -nP -iTCP:"$ENDPOINT_PORT" -sTCP:LISTEN || true
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
