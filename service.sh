#!/system/bin/sh
MODDIR=${0%/*}
STATUS="$MODDIR/status.txt"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
if [ "$(grep -c '{"idx":1, "min": 1, "max": 2147483647}' "$P" 2>/dev/null)" = "2" ] \
  && grep -q '"range_min": 801' "$C" \
  && grep -q '"range_max": 2147483647' "$C" \
  && grep -q '"threshold": 50' "$C"; then
  printf '%s\n' 'ACTIVE: BasedOnCC index=1; LowSoh trigger=cycle>=801 AND raw SOH<=50' > "$STATUS"
else
  printf '%s\n' 'INACTIVE/PENDING: live configs do not yet match v1.2.0; reboot required' > "$STATUS"
fi
exit 0
