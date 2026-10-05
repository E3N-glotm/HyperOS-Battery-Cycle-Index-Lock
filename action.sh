#!/system/bin/sh
MODDIR=${0%/*}
echo "=== HyperOS Battery Cycle Index Lock ==="
cat "$MODDIR/status.txt" 2>/dev/null || echo "PENDING: reboot required"
echo
echo "Device : $(getprop ro.product.device)"
echo "Build  : $(getprop ro.build.version.incremental)"
echo "Cycle  : $(cat /sys/class/xm_power/fg_master/cyclecount 2>/dev/null)"
echo "UI SOH : $(cat /sys/class/xm_power/fg_master/soh_new 2>/dev/null)"
echo
echo "Active cyclecount maps:"
grep -n -A3 '"cyclecount_index_map"' /odm/etc/charger/BAA_config_pudding.json 2>/dev/null
echo
echo "Runtime policy: all cycle counts use cyclecount_index 1."
echo "The index 2/3/4 parameter blocks remain as unreachable OEM data only."
echo "Disable/uninstall + reboot restores the stock map."
