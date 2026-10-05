#!/system/bin/sh
MODDIR=${0%/*}
TAG=BatteryAgingPolicyLock
PUDDING=/odm/etc/charger/BAA_config_pudding.json
COMMON=/odm/etc/charger/BAA_config_common.json
PUDDING_PATCHED="$MODDIR/private/BAA_config_pudding.json"
COMMON_PATCHED="$MODDIR/private/BAA_config_common.json"
STATUS="$MODDIR/status.txt"

PUDDING_STOCK_SHA=470c21966dd8637eaf113532ccb4d0fb85ee2ac5763b50bcda3bc3ba33be9b25
PUDDING_PATCHED_SHA=f9a3bb27c9a574714683f939bad7fbfb4471c614252b74d9d4dcd255327464fb
COMMON_STOCK_SHA=6b8bd170810019ff7d144f8f11636dfb8140fbd6356ddfe71a50c8d08d3b2701
COMMON_PATCHED_SHA=989ee3ff894a17808b9d8b45cbdaa1fd7de981f4c79a5a21be506a5c0e2115b8

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

for f in "$PUDDING" "$COMMON" "$PUDDING_PATCHED" "$COMMON_PATCHED"; do
  [ -r "$f" ] || fail "required config unreadable: $f"
done

P_SRC="$(sha256sum "$PUDDING" 2>/dev/null | cut -d ' ' -f 1)"
C_SRC="$(sha256sum "$COMMON" 2>/dev/null | cut -d ' ' -f 1)"
P_DST="$(sha256sum "$PUDDING_PATCHED" 2>/dev/null | cut -d ' ' -f 1)"
C_DST="$(sha256sum "$COMMON_PATCHED" 2>/dev/null | cut -d ' ' -f 1)"

[ "$P_SRC" = "$PUDDING_STOCK_SHA" ] || [ "$P_SRC" = "$PUDDING_PATCHED_SHA" ] || fail "pudding config hash mismatch"
[ "$C_SRC" = "$COMMON_STOCK_SHA" ] || [ "$C_SRC" = "$COMMON_PATCHED_SHA" ] || fail "common config hash mismatch"
[ "$P_DST" = "$PUDDING_PATCHED_SHA" ] || fail "patched pudding hash mismatch"
[ "$C_DST" = "$COMMON_PATCHED_SHA" ] || fail "patched common hash mismatch"

[ "$(grep -c '{"idx":1, "min": 1, "max": 2147483647}' "$PUDDING_PATCHED" 2>/dev/null)" = "2" ] || fail "index-1 map validation failed"
[ "$(grep -c '"range_min": 801' "$COMMON_PATCHED" 2>/dev/null)" = "1" ] || fail "LowSoh min validation failed"
[ "$(grep -c '"range_max": 2147483647' "$COMMON_PATCHED" 2>/dev/null)" = "1" ] || fail "LowSoh max validation failed"
[ "$(grep -c '"threshold": 50' "$COMMON_PATCHED" 2>/dev/null)" = "1" ] || fail "LowSoh threshold validation failed"

for f in "$PUDDING_PATCHED" "$COMMON_PATCHED"; do
  chown 0:0 "$f" 2>/dev/null || true
  chmod 0644 "$f" || fail "cannot chmod $f"
  chcon u:object_r:vendor_configs_file:s0 "$f" 2>/dev/null || true
done

if [ -x /system/bin/nsenter ]; then
  /system/bin/nsenter -t 1 -m -- /system/bin/mount --bind "$PUDDING_PATCHED" "$PUDDING" || fail "pudding bind mount failed"
  /system/bin/nsenter -t 1 -m -- /system/bin/mount --bind "$COMMON_PATCHED" "$COMMON" || fail "common bind mount failed"
else
  /system/bin/mount --bind "$PUDDING_PATCHED" "$PUDDING" || fail "pudding bind mount failed"
  /system/bin/mount --bind "$COMMON_PATCHED" "$COMMON" || fail "common bind mount failed"
fi

[ "$(grep -c '{"idx":1, "min": 1, "max": 2147483647}' "$PUDDING" 2>/dev/null)" = "2" ] || fail "live index map verification failed"
[ "$(grep -c '"range_min": 801' "$COMMON" 2>/dev/null)" = "1" ] || fail "live LowSoh min verification failed"
[ "$(grep -c '"range_max": 2147483647' "$COMMON" 2>/dev/null)" = "1" ] || fail "live LowSoh max verification failed"
[ "$(grep -c '"threshold": 50' "$COMMON" 2>/dev/null)" = "1" ] || fail "live LowSoh threshold verification failed"

report "ACTIVE: BasedOnCC index=1 for all cycles; LowSoh only at cycle>=801 AND raw SOH<=50"
exit 0
