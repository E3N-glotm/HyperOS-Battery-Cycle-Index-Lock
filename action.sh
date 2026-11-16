#!/system/bin/sh
# v1.5.0-alpha.2: read-only diagnostics with an explicit reason code, so an
# inactive module is never mistaken for a working one and a safe fallback is
# never mistaken for a restored charging policy.
# Purely read-only: no mount, no unmount, no property change, no label change.
MODDIR=${0%/*}
META="$MODDIR/private/verified.sha256"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json

echo "=== HyperOS Battery Cycle + SOH Index Lock v1.5.0-alpha.2 ==="
cat "$MODDIR/status.txt" 2>/dev/null ||
  echo "State: no completed boot audit for this install"
echo "--- Last recorded boot audit ---"
cat "$MODDIR/diagnostics.txt" 2>/dev/null ||
  echo "No diagnostics record yet (installed by an older version: reboot or reinstall)"
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
echo "=== Read-only compatibility probe ==="
if [ -f "$MODDIR/bin/compat_probe.sh" ]; then
  /system/bin/sh "$MODDIR/bin/compat_probe.sh"
else
  echo "compat probe missing; reinstall to restore it"
fi
echo "=== OEM Battery Antiaging Service PID ==="
pidof vendor.xiaomi.hardware.batteryantiaging-service || true
echo "=== Claims boundary ==="
echo "Only a fingerprint-validated BAA pair may mount, and only after reboot."
echo "After a firmware update the previous install profile is expired: nothing"
echo "is force-mounted and the running firmware's stock OEM charging policy"
echo "remains in effect. Reinstall on the current firmware to revalidate, or"
echo "disable the module. Status is never inferred from the module being enabled."
echo "When mounted, this module intentionally defers OEM battery aging charging"
echo "reductions; long-term charging safety and cell life may be affected."
