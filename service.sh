#!/system/bin/sh
MODDIR=/data/adb/modules/battery_cycle_aging_switch_off
META="$MODDIR/private/verified.sha256"
STATUS="$MODDIR/status.txt"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
digest() { sha256sum "$1" 2>/dev/null | cut -d ' ' -f 1; }
[ -r "$META" ] || { echo "INACTIVE: no validated BAA metadata" > "$STATUS"; exit 0; }
P_NEW="$(sed -n 's/^P_NEW=//p' "$META")"
C_NEW="$(sed -n 's/^C_NEW=//p' "$META")"
if [ "$(expr "$P_NEW" : '[a-f0-9]*$')" = 64 ] &&
   [ "$(expr "$C_NEW" : '[a-f0-9]*$')" = 64 ] &&
   [ "$(digest "$P")" = "$P_NEW" ] && [ "$(digest "$C")" = "$C_NEW" ]; then
  if pidof vendor.xiaomi.hardware.batteryantiaging-service >/dev/null 2>&1; then
    echo "ACTIVE: vendor BAA service running; both validated encrypted overlays loaded" > "$STATUS"
  else
    echo "MOUNTED: encrypted overlays active, OEM BAA service not running" > "$STATUS"
  fi
else
  echo "INACTIVE: source version/profile changed or mount integrity verification failed" > "$STATUS"
fi
