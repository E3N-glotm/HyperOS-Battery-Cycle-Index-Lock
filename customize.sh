ui_print "- HyperOS Battery Cycle + SOH Index Lock"
ui_print "- v1.2.0 / author E3N"
ui_print "- Target: pudding / OS3.0.319.0.WPCCNXM"
ui_print "- BasedOnCC: cyclecount_index=1 for all cycle counts"
ui_print "- LowSoh: only cyclecount >= 801 AND raw SOH <= 50"

P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
P_STOCK=470c21966dd8637eaf113532ccb4d0fb85ee2ac5763b50bcda3bc3ba33be9b25
P_V11=f9a3bb27c9a574714683f939bad7fbfb4471c614252b74d9d4dcd255327464fb
C_STOCK=6b8bd170810019ff7d144f8f11636dfb8140fbd6356ddfe71a50c8d08d3b2701
C_PATCHED=989ee3ff894a17808b9d8b45cbdaa1fd7de981f4c79a5a21be506a5c0e2115b8

[ "$(getprop ro.product.device)" = "pudding" ] || abort "! Unsupported device"
[ "$(getprop ro.build.version.incremental)" = "OS3.0.319.0.WPCCNXM" ] || abort "! Unsupported ROM build"
[ "$(getprop ro.build.version.sdk)" = "36" ] || abort "! Unsupported SDK"
[ -r "$P" ] || abort "! Cannot read pudding BAA config"
[ -r "$C" ] || abort "! Cannot read common BAA config"

mkdir -p "$MODPATH/private" || abort "! Cannot create private dir"

P_SHA="$(sha256sum "$P" | cut -d ' ' -f 1)"
if [ "$P_SHA" = "$P_STOCK" ]; then
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
  {print}' "$P" > "$MODPATH/private/BAA_config_pudding.json" || abort "! Failed to patch pudding config"
elif [ "$P_SHA" = "$P_V11" ]; then
  cp -af "$P" "$MODPATH/private/BAA_config_pudding.json" || abort "! Failed to carry forward v1.1 pudding config"
else
  abort "! Pudding config hash mismatch (OTA/other modification)"
fi

[ "$(sha256sum "$MODPATH/private/BAA_config_pudding.json" | cut -d ' ' -f 1)" = "$P_V11" ] || abort "! Patched pudding hash mismatch"

C_SHA="$(sha256sum "$C" | cut -d ' ' -f 1)"
if [ "$C_SHA" = "$C_STOCK" ]; then
  sed \
    -e 's/"range_min": 200/"range_min": 801/' \
    -e 's/"range_max": 800/"range_max": 2147483647/' \
    -e 's/"threshold": 85/"threshold": 50/' \
    "$C" > "$MODPATH/private/BAA_config_common.json" || abort "! Failed to patch common config"
elif [ "$C_SHA" = "$C_PATCHED" ]; then
  cp -af "$C" "$MODPATH/private/BAA_config_common.json" || abort "! Failed to carry forward common config"
else
  abort "! Common config hash mismatch (OTA/other modification)"
fi

[ "$(sha256sum "$MODPATH/private/BAA_config_common.json" | cut -d ' ' -f 1)" = "$C_PATCHED" ] || abort "! Patched common hash mismatch"

set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/private/BAA_config_pudding.json" 0 0 0644
set_perm "$MODPATH/private/BAA_config_common.json" 0 0 0644

ui_print "- Validation passed"
ui_print "- Reboot required for the new LowSoh trigger to take effect"
