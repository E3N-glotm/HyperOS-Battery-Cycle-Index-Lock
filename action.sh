#!/system/bin/sh
# v1.5: report real battery data and current-vs-pinned OEM BAA fingerprints.
# Purely read-only. Does not change charging policy or mount state.
MODDIR=${0%/*}
META="$MODDIR/private/verified.sha256"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json

echo "=== HyperOS Battery Cycle + SOH Index Lock v1.5.0-alpha.1 ==="
cat "$MODDIR/status.txt" 2>/dev/null || echo "State: no completed boot audit"
echo "ROM: $(getprop ro.build.version.incremental)"
printf "Device: "
getprop ro.product.device
echo "=== OEM Fuel Gauge (read-only) ==="
for key in cyclecount soh soh_new; do
  printf '%s=' "$key"
  cat "/sys/class/xm_power/fg_master/$key" 2>/dev/null || echo unreadable
done

echo "=== Current PID1-visible BAA_ENC SHA-256 ==="
if [ -x /system/bin/nsenter ]; then
  /system/bin/nsenter -t 1 -m -- /system/bin/sha256sum "$P" "$C" 2>/dev/null ||
    echo "OEM PID1 mount namespace unavailable"
else
  /system/bin/sha256sum "$P" "$C" 2>/dev/null
fi
echo "=== Installer-pinned OEM/overlay fingerprints ==="
if [ -r "$META" ]; then
  grep -E '^(P_SOURCE|C_SOURCE|P_NEW|C_NEW|mode|device)=' "$META"
else
  echo "Not generated/validated"
fi
echo "=== OEM Battery Antiaging Service PID ==="
pidof vendor.xiaomi.hardware.batteryantiaging-service || true
echo "=== Safety notice ==="
echo "Only validated BAA profiles may mount after reboot."
echo "This module suppresses OEM battery aging charging reductions."
echo "Long-term charging safety and cell life may be affected."
echo "Disable the module and reboot to restore OEM charging policy."
