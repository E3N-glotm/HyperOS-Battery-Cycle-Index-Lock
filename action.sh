#!/system/bin/sh
MODDIR=/data/adb/modules/battery_cycle_aging_switch_off
echo "=== HyperOS Battery Cycle + SOH Index Lock v1.3.0 ==="
cat "$MODDIR/status.txt" 2>/dev/null || echo "Status unavailable"
echo "Build: $(getprop ro.build.version.incremental)"
for key in cyclecount soh soh_new; do
  printf '%s=' "$key"
  cat "/sys/class/xm_power/fg_master/$key" 2>/dev/null || echo unreadable
done
echo "=== Live BAA_ENC config SHA-256 ==="
sha256sum /odm/etc/charger/BAA_config_pudding.json /odm/etc/charger/BAA_config_common.json 2>/dev/null
echo "=== Vendor batteryantiaging service PID ==="
pidof vendor.xiaomi.hardware.batteryantiaging-service || true
echo "=== OEM protection ==="
echo "Other thermal, overvoltage and overcurrent tables remain unchanged."
echo "Disable module and reboot to restore stock config."
