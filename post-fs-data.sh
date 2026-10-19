#!/system/bin/sh
MODDIR=/data/adb/modules/battery_cycle_aging_switch_off
STATUS="$MODDIR/status.txt"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
PP="$MODDIR/private/BAA_config_pudding.json"
CP="$MODDIR/private/BAA_config_common.json"
META="$MODDIR/private/verified.sha256"
PS=a03abd594154588667684b8c09ceccbd51e5d9875fc827e0eee08d8d4c1ecad5
CS=83aac16d8bed63170c856b41b1d280e1720a2738131b5de326ae40dbcffdfd44
say() { printf '%s\n' "$1" > "$STATUS"; /system/bin/log -p i -t BatteryAgingPolicyLock "$1" 2>/dev/null || true; }
fail() { say "INACTIVE: $*; stock preserved"; exit 0; }
digest() { sha256sum "$1" 2>/dev/null | cut -d ' ' -f1; }
ns() { /system/bin/nsenter -t 1 -m -- "$@"; }
[ "$(getprop ro.product.device)" = pudding ] || fail "device mismatch"
[ "$(getprop ro.build.version.incremental)" = OS4.0.4.0.XPCCNXM ] || fail "ROM mismatch"
[ "$(getprop ro.build.version.sdk)" = 37 ] || fail "API mismatch"
[ -x /system/bin/nsenter ] || fail "nsenter unavailable"
[ -r "$META" ] || fail "no installer validation metadata"
P_NEW="$(sed -n 's/^P_NEW=//p' "$META")"
C_NEW="$(sed -n 's/^C_NEW=//p' "$META")"
[ "$(expr "$P_NEW" : '[0-9a-f]*$')" = 64 ] || fail "invalid pudding SHA metadata"
[ "$(expr "$C_NEW" : '[0-9a-f]*$')" = 64 ] || fail "invalid common SHA metadata"
for f in "$P" "$C" "$PP" "$CP"; do
  [ -r "$f" ] || fail "missing $f"
  [ "$(head -c 8 "$f")" = BAA_ENC: ] || fail "invalid encrypted config header"
done
[ "$(digest "$PP")" = "$P_NEW" ] || fail "private pudding ciphertext mismatch"
[ "$(digest "$CP")" = "$C_NEW" ] || fail "private common ciphertext mismatch"
SOURCE_P="$(ns /system/bin/sha256sum "$P" 2>/dev/null | cut -d' ' -f1)"
SOURCE_C="$(ns /system/bin/sha256sum "$C" 2>/dev/null | cut -d' ' -f1)"
if [ "$SOURCE_P" = "$P_NEW" ] && [ "$SOURCE_C" = "$C_NEW" ]; then
  say "MOUNTED: BAA_ENC configs already active"
  exit 0
fi
[ "$SOURCE_P" = "$PS" ] && [ "$SOURCE_C" = "$CS" ] || fail "source files not the pinned OEM pair"
chown 0:0 "$PP" "$CP" || fail "chown failed"
chmod 0644 "$PP" "$CP" || fail "chmod failed"
chcon u:object_r:batteryantiaging_cfg_file:s0 "$PP" "$CP" || fail "SELinux label failed"
ns /system/bin/mount --bind "$PP" "$P" || fail "pudding mount failed"
if ! ns /system/bin/mount --bind "$CP" "$C"; then
  ns /system/bin/umount "$P" 2>/dev/null
  fail "common mount failed; rollback pudding"
fi
LIVE_P="$(ns /system/bin/sha256sum "$P" 2>/dev/null | cut -d' ' -f1)"
LIVE_C="$(ns /system/bin/sha256sum "$C" 2>/dev/null | cut -d' ' -f1)"
if [ "$LIVE_P" != "$P_NEW" ] || [ "$LIVE_C" != "$C_NEW" ]; then
  ns /system/bin/umount "$C" 2>/dev/null
  ns /system/bin/umount "$P" 2>/dev/null
  fail "runtime ciphertext SHA mismatch; both mounts rolled back"
fi
say "MOUNTED: BAA_ENC index=1 CN/GL; LowSoh cycle>=801 and raw SOH<=50"
exit 0
