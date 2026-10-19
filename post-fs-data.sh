#!/system/bin/sh
MODDIR=/data/adb/modules/battery_cycle_aging_switch_off
STATUS="$MODDIR/status.txt"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
PP="$MODDIR/private/BAA_config_pudding.json"
CP="$MODDIR/private/BAA_config_common.json"
META="$MODDIR/private/verified.sha256"
say() { printf '%s\n' "$1" > "$STATUS"; /system/bin/log -p i -t BatteryAgingPolicyLock "$1" 2>/dev/null || true; }
fail() { say "INACTIVE: $*; stock configuration retained"; exit 0; }
digest() { sha256sum "$1" 2>/dev/null | cut -d ' ' -f 1; }
valid() { [ "$(expr "$1" : '[a-f0-9]*$')" = 64 ]; }
ns() { /system/bin/nsenter -t 1 -m -- "$@"; }
[ "$(getprop ro.product.device)" = pudding ] || fail "device hardware profile changed"
[ -x /system/bin/nsenter ] || fail "PID1 mount API unavailable"
[ -r /vendor/lib64/libbaa_common.so ] || fail "OEM BAA decoder ABI absent"
[ -r "$META" ] || fail "installer validation metadata missing"
P_SOURCE="$(sed -n 's/^P_SOURCE=//p' "$META")"
C_SOURCE="$(sed -n 's/^C_SOURCE=//p' "$META")"
P_NEW="$(sed -n 's/^P_NEW=//p' "$META")"
C_NEW="$(sed -n 's/^C_NEW=//p' "$META")"
for sha in "$P_SOURCE" "$C_SOURCE" "$P_NEW" "$C_NEW"; do
  valid "$sha" || fail "invalid installer SHA metadata"
done
for f in "$P" "$C" "$PP" "$CP"; do
  [ -r "$f" ] || fail "missing $f"
  [ "$(head -c 8 "$f")" = BAA_ENC: ] || fail "unsupported format $f"
done
[ "$(digest "$PP")" = "$P_NEW" ] && [ "$(digest "$CP")" = "$C_NEW" ] ||
  fail "private encrypted BAA overlay mutated"
LIVE_P="$(ns /system/bin/sha256sum "$P" 2>/dev/null | cut -d ' ' -f 1)"
LIVE_C="$(ns /system/bin/sha256sum "$C" 2>/dev/null | cut -d ' ' -f 1)"
if [ "$LIVE_P" = "$P_NEW" ] && [ "$LIVE_C" = "$C_NEW" ]; then
  say "MOUNTED: verified encrypted BAA pair already active"
  exit 0
fi
# Detect changes in source after OTA, not Android build version changes.
[ "$LIVE_P" = "$P_SOURCE" ] && [ "$LIVE_C" = "$C_SOURCE" ] ||
  fail "OEM BAA input fingerprint changed; reinstall to reprobe firmware"
chown 0:0 "$PP" "$CP" || fail chown
chmod 0644 "$PP" "$CP" || fail chmod
chcon u:object_r:batteryantiaging_cfg_file:s0 "$PP" "$CP" || fail label
ns /system/bin/mount --bind "$PP" "$P" || fail "pudding bind failed"
if ! ns /system/bin/mount --bind "$CP" "$C"; then
  ns /system/bin/umount "$P" 2>/dev/null
  fail "common bind failed; rolled back"
fi
if [ "$(ns /system/bin/sha256sum "$P" 2>/dev/null | cut -d ' ' -f 1)" != "$P_NEW" ] ||
   [ "$(ns /system/bin/sha256sum "$C" 2>/dev/null | cut -d ' ' -f 1)" != "$C_NEW" ]; then
  ns /system/bin/umount "$C" 2>/dev/null
  ns /system/bin/umount "$P" 2>/dev/null
  fail "active encrypted BAA hashes differ; rolled back"
fi
say "MOUNTED: BAA_ENC OEM schema; CN/GL index1; LowSoh cycles>=801 raw SOH<=50"
