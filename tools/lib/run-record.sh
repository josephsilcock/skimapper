# The harness's lines in the E2E run record, on stdout beside the app's. Source, don't execute.

# The E2E group the lines belong to; tools/e2e sets it per group.
RUN_GROUP="-"

# Copies stdin to stdout, each line stamped with the given tag, the group and the time.
stamp_lines() {
  node "$TOOLS_DIR/lib/stamp-lines.ts" "$1" "$RUN_GROUP"
}

record_milestone() {
  echo "$*" | stamp_lines harness
}

# Which processes hold the endpoint port; none is a valid answer.
record_port_holders() {
  local holders
  holders="$(port_holders)"
  echo "${holders:-nothing holds port $ENDPOINT_PORT}" | stamp_lines port
}

DEVICE_LOG_PID=""

# While Patrol runs on iOS: the app process's networking lines from the simulator's log, stamped.
# The emulator has no counterpart worth the noise.
start_device_log() {
  local platform="$1" device="$2"
  [[ "$platform" == ios ]] || return 0
  xcrun simctl spawn "$device" log stream --style compact --level debug --predicate 'process == "Runner"
    AND (subsystem BEGINSWITH "com.apple.network" OR subsystem BEGINSWITH "com.apple.CFNetwork"
    OR subsystem BEGINSWITH "com.apple.dnssd" OR subsystem == "com.apple.libinfo")' \
    > >(stamp_lines device) 2>&1 &
  DEVICE_LOG_PID=$!
}

stop_device_log() {
  [[ -n "$DEVICE_LOG_PID" ]] || return 0
  kill "$DEVICE_LOG_PID" 2>/dev/null || true
  wait "$DEVICE_LOG_PID" 2>/dev/null || true
  DEVICE_LOG_PID=""
}
