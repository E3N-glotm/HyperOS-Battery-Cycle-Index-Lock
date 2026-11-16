#!/system/bin/sh
# Read-only OTA compatibility probe. Run it before and after a HyperOS update to
# record whether the OEM BAA inputs changed and whether this install's profile is
# still valid for the firmware that is actually running.
#
# This probe never mounts, never unmounts, never remounts, never changes a
# label, never touches SELinux, never writes to /odm, /vendor or /sys, and never
# changes a system property. It only reads and prints.
MODDIR="$(cd "${0%/*}/.." && pwd)"
META="$MODDIR/private/verified.sha256"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
digest() { sha256sum "$1" 2>/dev/null | cut -d ' ' -f 1; }
valid() { [ "$(expr "$1" : '[a-f0-9]*$')" = 64 ]; }
ns() { /system/bin/nsenter -t 1 -m -- "$@"; }
fmt() {
  [ "$(head -c 8 "$1" 2>/dev/null)" = BAA_ENC: ] && printf yes || printf no
}
BUILD="$(getprop ro.build.version.incremental)"
SDK="$(getprop ro.build.version.sdk)"

echo "=== HyperOS BAA OTA compatibility probe (read-only) ==="
echo "device=$(getprop ro.product.device)"
echo "oem_build=$BUILD"
echo "android_sdk=$SDK"
echo "probe_write_policy=none"
echo
echo "=== OEM BAA inputs as this process sees them ==="
for f in "$P" "$C"; do
  printf 'path=%s readable=%s format_baa_enc=%s sha256=%s\n' "$f" \
    "$([ -r "$f" ] && printf yes || printf no)" "$(fmt "$f")" "$(digest "$f")"
done
echo
echo "=== PID1 namespace view (what the OEM charger and BAA stack read) ==="
if [ -x /system/bin/nsenter ]; then
  ns /system/bin/sha256sum "$P" "$C" 2>/dev/null || echo "pid1_namespace=unavailable"
else
  echo "pid1_namespace=nsenter_missing"
fi
echo
echo "=== OEM capability presence ==="
printf 'vendor_baa_decoder_abi=%s\n' \
  "$([ -r /vendor/lib64/libbaa_common.so ] && printf present || printf missing)"
printf 'vendor_linker_namespace_declared=%s\n' \
  "$(grep -Fqx 'dir.vendor = /data/local/tests/vendor' /linkerconfig/ld.config.txt 2>/dev/null && printf yes || printf no)"
printf 'oem_baa_service=%s\n' \
  "$(pidof vendor.xiaomi.hardware.batteryantiaging-service 2>/dev/null || echo not_running)"
printf 'odm_mount_line=%s\n' \
  "$(mount 2>/dev/null | grep -w /odm | head -1)"
echo
echo "=== Real battery read-only sources ==="
printf 'fg_soh=%s\n' \
  "$(/system/bin/cat /sys/class/xm_power/fg_master/soh 2>/dev/null || echo unreadable)"
printf 'fg_cyclecount=%s\n' \
  "$(/system/bin/cat /sys/class/xm_power/fg_master/cyclecount 2>/dev/null || echo unreadable)"
printf 'power_supply_cycle_count=%s\n' \
  "$(/system/bin/cat /sys/class/power_supply/battery/cycle_count 2>/dev/null || echo unreadable)"
printf 'power_supply_charge_full_uAh=%s\n' \
  "$(/system/bin/cat /sys/class/power_supply/battery/charge_full 2>/dev/null || echo unreadable)"
printf 'power_supply_charge_full_design_uAh=%s\n' \
  "$(/system/bin/cat /sys/class/power_supply/battery/charge_full_design 2>/dev/null || echo unreadable)"
echo
echo "=== Install profile validity against the running firmware ==="
if [ -r "$META" ]; then
  P_SRC="$(sed -n 's/^P_SOURCE=//p' "$META")"
  C_SRC="$(sed -n 's/^C_SOURCE=//p' "$META")"
  P_NEW="$(sed -n 's/^P_NEW=//p' "$META")"
  C_NEW="$(sed -n 's/^C_NEW=//p' "$META")"
  LIVE_P="$(ns /system/bin/sha256sum "$P" 2>/dev/null | cut -d ' ' -f 1)"
  LIVE_C="$(ns /system/bin/sha256sum "$C" 2>/dev/null | cut -d ' ' -f 1)"
  printf 'pinned_p_source=%s\n' "${P_SRC:-absent}"
  printf 'pinned_c_source=%s\n' "${C_SRC:-absent}"
  printf 'pinned_p_new=%s\n' "${P_NEW:-absent}"
  printf 'pinned_c_new=%s\n' "${C_NEW:-absent}"
  if ! valid "$P_SRC" || ! valid "$C_SRC" || ! valid "$P_NEW" || ! valid "$C_NEW"; then
    echo "verdict=REASON_METADATA_MALFORMED reinstall_required"
  elif [ -z "$LIVE_P" ] || [ -z "$LIVE_C" ]; then
    echo "verdict=REASON_OEM_INPUT_MISSING stock_configuration_retained"
  elif [ "$LIVE_P" = "$P_NEW" ] && [ "$LIVE_C" = "$C_NEW" ]; then
    echo "verdict=MOUNT_VERIFIED profile_valid_for_running_firmware"
  elif [ "$LIVE_P" = "$P_SRC" ] && [ "$LIVE_C" = "$C_SRC" ]; then
    echo "verdict=REASON_INTEGRITY_MISMATCH stock_configuration_retained"
  else
    echo "verdict=REASON_OEM_SOURCE_CHANGED profile_expired_for_running_firmware reinstall_to_revalidate"
  fi
else
  echo "verdict=REASON_NO_VALIDATED_METADATA reinstall_required"
fi
echo
echo "Claims boundary: this probe only reports. It does not restore a charging"
echo "policy, does not mount anything, and does not certify long-term charging"
echo "safety or real cell health."
