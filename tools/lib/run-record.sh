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
  command -v lsof >/dev/null || fail "lsof is not installed; the E2E run record needs it for port snapshots"
  local holders
  holders="$(lsof -nP -iTCP:"$ENDPOINT_PORT" || true)"
  echo "${holders:-nothing holds port $ENDPOINT_PORT}" | stamp_lines port
}
