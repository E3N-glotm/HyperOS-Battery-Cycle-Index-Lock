ui_print "- HyperOS Battery Cycle Index Lock"
ui_print "- Target: pudding / OS3.0.319.0.WPCCNXM"
ui_print "- cyclecount_index is locked to 1 for all cycle counts"
ui_print "- OEM safety protections are retained"

TARGET=/odm/etc/charger/BAA_config_pudding.json
STOCK_SHA=470c21966dd8637eaf113532ccb4d0fb85ee2ac5763b50bcda3bc3ba33be9b25

[ "$(getprop ro.product.device)" = "pudding" ] || abort "! Unsupported device"
[ "$(getprop ro.build.version.incremental)" = "OS3.0.319.0.WPCCNXM" ] || abort "! Unsupported ROM build"
[ -r "$TARGET" ] || abort "! Cannot read stock BAA config"
[ "$(sha256sum "$TARGET" | cut -d ' ' -f 1)" = "$STOCK_SHA" ] || abort "! Stock BAA config hash mismatch"

mkdir -p "$MODPATH/private" || abort "! Cannot create private dir"

awk 'BEGIN{inmap=0}
 /"cyclecount_index_map"[[:space:]]*:/ {
   print
   getline
   print "                    {\"idx\":1, \"min\": 1, \"max\": 2147483647}"
   inmap=1
   next
 }
 inmap {
   if ($0 ~ /^[[:space:]]*\],[[:space:]]*$/) {
     print
     inmap=0
   }
   next
 }
 {print}' "$TARGET" > "$MODPATH/private/BAA_config_pudding.json" || abort "! Failed to generate patched config"

[ "$(grep -c '"cyclecount_index_map"' "$MODPATH/private/BAA_config_pudding.json")" = "2" ] || abort "! Map validation failed"
[ "$(grep -c '{"idx":1, "min": 1, "max": 2147483647}' "$MODPATH/private/BAA_config_pudding.json")" = "2" ] || abort "! Index-1 map validation failed"
[ "$(sha256sum "$MODPATH/private/BAA_config_pudding.json" | cut -d ' ' -f 1)" = "f9a3bb27c9a574714683f939bad7fbfb4471c614252b74d9d4dcd255327464fb" ] || abort "! Patched config hash mismatch"

set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/private/BAA_config_pudding.json" 0 0 0644

ui_print "- Generated: idx=1, min=1, max=2147483647 (CN + GL)"
ui_print "- Reboot required"
