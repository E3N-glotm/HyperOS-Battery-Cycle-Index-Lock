#!/system/bin/sh
MODDIR=${0%/*}
STATUS="$MODDIR/status.txt"
if [ "$(grep -c '{"idx":1, "min": 1, "max": 2147483647}' /odm/etc/charger/BAA_config_pudding.json 2>/dev/null)" = "2" ]; then
  printf '%s\n' 'ACTIVE: cyclecount_index=1 covers 1..2147483647 for CN and GL battery profiles' > "$STATUS"
else
  printf '%s\n' 'INACTIVE: stock cyclecount map visible; check early-boot status' > "$STATUS"
fi
exit 0
