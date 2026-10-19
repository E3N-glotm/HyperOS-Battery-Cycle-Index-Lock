#!/system/bin/sh
MODDIR=/data/adb/modules/battery_cycle_aging_switch_off
STATUS="$MODDIR/status.txt"
META="$MODDIR/private/verified.sha256"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
digest() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
[ -r "$META" ] || { echo "INACTIVE: no verified installer metadata" > "$STATUS"; exit 0; }
P_NEW="$(sed -n 's/^P_NEW=//p' "$META")"
C_NEW="$(sed -n 's/^C_NEW=//p' "$META")"
if [ "$(expr "$P_NEW" : '[0-9a-f]*$')" = 64 ] && [ "$(expr "$C_NEW" : '[0-9a-f]*$')" = 64 ] &&
   [ "$(digest "$P")" = "$P_NEW" ] && [ "$(digest "$C")" = "$C_NEW" ]; then
  if pidof vendor.xiaomi.hardware.batteryantiaging-service >/dev/null 2>&1; then
    echo "ACTIVE: OEM BAA_ENC configurations mounted, anti-aging service running, CN/GL index1, LowSoh cycle>=801 AND raw SOH<=50" > "$STATUS"
  else
    echo "MOUNTED: valid BAA_ENC mounts; batteryantiaging service not running" > "$STATUS"
  fi
else
  echo "INACTIVE: OEM stock retained or runtime mount fingerprint mismatch" > "$STATUS"
fi
exit 0
