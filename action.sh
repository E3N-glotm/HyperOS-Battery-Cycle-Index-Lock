#!/system/bin/sh
MODDIR=${0%/*}
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
echo "=== HyperOS Battery Cycle + SOH Index Lock ==="
cat "$MODDIR/status.txt" 2>/dev/null || echo "Status unavailable"
echo
echo "Device : $(getprop ro.product.device)"
echo "Build  : $(getprop ro.build.version.incremental)"
echo "Cycle  : $(cat /sys/class/xm_power/fg_master/cyclecount 2>/dev/null)"
echo "Raw SOH: $(cat /sys/class/xm_power/fg_master/soh 2>/dev/null)"
echo "UI SOH : $(cat /sys/class/xm_power/fg_master/soh_new 2>/dev/null)"
echo
echo "BasedOnCC live map:"
grep -n -A3 '"cyclecount_index_map"' "$P" 2>/dev/null
echo
echo "LowSoh live trigger:"
grep -n -A16 '"LowSoh-FvDown"' "$C" 2>/dev/null
echo
echo "Expected: cyclecount >= 801 AND raw SOH <= 50."
echo "Disable/uninstall + reboot restores the stock Xiaomi policy."
