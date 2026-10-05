#!/system/bin/sh
MODDIR=${0%/*}
TAG=BatteryCycleIndexLock
TARGET=/odm/etc/charger/BAA_config_pudding.json
PATCHED="$MODDIR/private/BAA_config_pudding.json"
STATUS="$MODDIR/status.txt"
STOCK_SHA=470c21966dd8637eaf113532ccb4d0fb85ee2ac5763b50bcda3bc3ba33be9b25
PATCHED_SHA=f9a3bb27c9a574714683f939bad7fbfb4471c614252b74d9d4dcd255327464fb

report() {
  printf '%s\n' "$1" > "$STATUS"
  /system/bin/log -p i -t "$TAG" "$1" 2>/dev/null || true
}
fail() {
  report "FAILED: $*"
  exit 0
}

[ "$(getprop ro.product.device)" = "pudding" ] || fail "device mismatch; stock retained"
[ "$(getprop ro.build.version.incremental)" = "OS3.0.319.0.WPCCNXM" ] || fail "ROM mismatch; stock retained"
[ "$(getprop ro.build.version.sdk)" = "36" ] || fail "SDK mismatch; stock retained"
[ -r "$TARGET" ] || fail "stock config unreadable"
[ -r "$PATCHED" ] || fail "patched config missing"

SRC_SHA="$(sha256sum "$TARGET" 2>/dev/null | cut -d ' ' -f 1)"
DST_SHA="$(sha256sum "$PATCHED" 2>/dev/null | cut -d ' ' -f 1)"
[ "$SRC_SHA" = "$STOCK_SHA" ] || fail "stock hash mismatch; OTA/other modification detected"
[ "$DST_SHA" = "$PATCHED_SHA" ] || fail "patched file hash mismatch"

[ "$(grep -c '"cyclecount_index_map"' "$PATCHED" 2>/dev/null)" = "2" ] || fail "unexpected map count"
[ "$(grep -c '{"idx":1, "min": 1, "max": 2147483647}' "$PATCHED" 2>/dev/null)" = "2" ] || fail "index-1 full-range map validation failed"
[ "$(grep -c '{"idx":2, "min":' "$PATCHED" 2>/dev/null)" = "0" ] || fail "index 2 still mapped"
[ "$(grep -c '{"idx":3, "min":' "$PATCHED" 2>/dev/null)" = "0" ] || fail "index 3 still mapped"
[ "$(grep -c '{"idx":4, "min":' "$PATCHED" 2>/dev/null)" = "0" ] || fail "index 4 still mapped"

chown 0:0 "$PATCHED" 2>/dev/null || true
chmod 0644 "$PATCHED" || fail "cannot chmod patched config"
chcon u:object_r:vendor_configs_file:s0 "$PATCHED" 2>/dev/null || true

if [ -x /system/bin/nsenter ]; then
  /system/bin/nsenter -t 1 -m -- /system/bin/mount --bind "$PATCHED" "$TARGET" || fail "PID1 bind mount failed"
else
  /system/bin/mount --bind "$PATCHED" "$TARGET" || fail "bind mount failed"
fi

[ "$(grep -c '{"idx":1, "min": 1, "max": 2147483647}' "$TARGET" 2>/dev/null)" = "2" ] || fail "live mount verification failed"
report "ACTIVE: cyclecount_index locked to 1 for all cycle counts; OEM safety protections retained"
exit 0
