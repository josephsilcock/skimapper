# Boots the dev config's simulator / emulator and prints its device id. Source, don't execute.

ios_simulator_udid() {
  xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
matches = [d["udid"] for runtime, devices in json.load(sys.stdin)["devices"].items()
           if "iOS" in runtime for d in devices if d["name"] == name]
print(matches[-1] if matches else "")
' "$IOS_SIMULATOR"
}

boot_ios_simulator() {
  local udid
  udid="$(ios_simulator_udid)"
  [[ -n "$udid" ]] || fail "iOS simulator '$IOS_SIMULATOR' (tools/dev.env IOS_SIMULATOR) is not available"
  xcrun simctl bootstatus "$udid" -b >/dev/null || fail "iOS simulator '$IOS_SIMULATOR' failed to boot"
  echo "$udid"
}

running_emulator_serial() {
  local serial
  for serial in $("$ADB" devices | awk '/^emulator-/ {print $1}'); do
    if [[ "$("$ADB" -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d '\r')" == "$ANDROID_AVD" ]]; then
      echo "$serial"
      return
    fi
  done
}

boot_android_emulator() {
  "$ANDROID_SDK/emulator/emulator" -list-avds | grep -qx "$ANDROID_AVD" \
    || fail "Android AVD '$ANDROID_AVD' (tools/dev.env ANDROID_AVD) is not available"
  local serial
  serial="$(running_emulator_serial)"
  if [[ -z "$serial" ]]; then
    nohup "$ANDROID_SDK/emulator/emulator" -avd "$ANDROID_AVD" -no-snapshot-save -no-boot-anim \
      >"${TMPDIR:-/tmp}/skimapper-emulator.log" 2>&1 &
    for _ in $(seq 1 120); do
      serial="$(running_emulator_serial)"
      [[ -n "$serial" ]] && break
      sleep 2
    done
    [[ -n "$serial" ]] || fail "Android AVD '$ANDROID_AVD' did not start"
  fi
  "$ADB" -s "$serial" wait-for-device
  for _ in $(seq 1 120); do
    [[ "$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
    sleep 2
  done
  [[ "$("$ADB" -s "$serial" shell getprop sys.boot_completed | tr -d '\r')" == "1" ]] \
    || fail "Android AVD '$ANDROID_AVD' did not finish booting"
  echo "$serial"
}

boot_device() {
  case "$1" in
    ios) boot_ios_simulator ;;
    android) boot_android_emulator ;;
  esac
}

# Newer Xcode ships DeviceHub in place of Simulator.app; the booted simulator works without either.
show_simulator_window() {
  open -a Simulator 2>/dev/null || open -a DeviceHub 2>/dev/null \
    || echo "note: no Simulator or DeviceHub app to show the simulator; it is running headless" >&2
}
