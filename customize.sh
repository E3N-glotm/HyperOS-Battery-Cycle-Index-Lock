#!/system/bin/sh
# v1.3.0: decrypt and rebuild on the user's exact OEM firmware.
# Fail closed. Never redistribute vendor encrypted charging configurations.
ui_print "- HyperOS Battery Cycle + SOH Index Lock v1.3.0 / E3N"
ui_print "- Xiaomi pudding / HyperOS OS4.0.4.0.XPCCNXM / API 37 only"
ui_print "- Both OEM BAA_ENC files are generated on this device"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
PS=a03abd594154588667684b8c09ceccbd51e5d9875fc827e0eee08d8d4c1ecad5
CS=83aac16d8bed63170c856b41b1d280e1720a2738131b5de326ae40dbcffdfd44
# Upgrade fingerprints: original verified v1.3.0 hotfix applied on this exact device.
P_HOTFIX=21f267901bbc09981e37538749ef94275c23ffeac88e95bd44658fd02f5e8759
C_HOTFIX=f7f41e1c649ba43ca3eee3378e75356b26de3ab54179d77f8c261688f9e9689c
digest() { sha256sum "$1" 2>/dev/null | cut -d ' ' -f 1; }
[ "$(getprop ro.product.device)" = pudding ] || abort "! Not Xiaomi pudding"
[ "$(getprop ro.build.version.incremental)" = OS4.0.4.0.XPCCNXM ] || abort "! Unsupported ROM"
[ "$(getprop ro.build.version.sdk)" = 37 ] || abort "! Unsupported Android API"
[ -r "$P" ] && [ -r "$C" ] || abort "! OEM BAA files unavailable"
[ "$(head -c 8 "$P")" = BAA_ENC: ] || abort "! Pudding not BAA_ENC"
[ "$(head -c 8 "$C")" = BAA_ENC: ] || abort "! Common not BAA_ENC"
mkdir -p "$MODPATH/private" || abort "! Cannot create private staging directory"
PP="$MODPATH/private/BAA_config_pudding.json"
CP="$MODPATH/private/BAA_config_common.json"
P_ACTUAL="$(digest "$P")"
C_ACTUAL="$(digest "$C")"
if [ "$P_ACTUAL" = "$PS" ] && [ "$C_ACTUAL" = "$CS" ]; then
  ui_print "- Stock OEM pair verified; building private encrypted configs"
  [ -x "$MODPATH/bin/baa_patch" ] || chmod 0755 "$MODPATH/bin/baa_patch"
  "$MODPATH/bin/baa_patch" "$P" "$C" "$PP" "$CP" || abort "! Vendor decryption, JSON verification, or encryption failed"
elif [ "$P_ACTUAL" = "$P_HOTFIX" ] && [ "$C_ACTUAL" = "$C_HOTFIX" ]; then
  OLD=/data/adb/modules/battery_cycle_aging_switch_off
  [ -f "$OLD/module.prop" ] || abort "! Unrecognized pre-existing hotfix"
  grep -q '^version=1.3.0$' "$OLD/module.prop" || abort "! Hotfix version mismatch"
  [ "$(digest "$OLD/private/BAA_config_pudding.json")" = "$P_HOTFIX" ] || abort "! Hotfix pudding source mismatch"
  [ "$(digest "$OLD/private/BAA_config_common.json")" = "$C_HOTFIX" ] || abort "! Hotfix common source mismatch"
  ui_print "- Verified v1.3.0 on-device hotfix; carrying generated ciphertext forward"
  cp "$OLD/private/BAA_config_pudding.json" "$PP" || abort "! Failed to copy hotfix pudding config"
  cp "$OLD/private/BAA_config_common.json" "$CP" || abort "! Failed to copy hotfix common config"
else
  abort "! Unknown OEM/modified BAA config SHA-256; original retained"
fi
[ "$(head -c 8 "$PP")" = BAA_ENC: ] && [ "$(head -c 8 "$CP")" = BAA_ENC: ] || abort "! Generated ciphertext missing magic"
NP="$(digest "$PP")"
NC="$(digest "$CP")"
[ "$(expr "$NP" : '[0-9a-f]*$')" = 64 ] || abort "! Invalid pudding digest"
[ "$(expr "$NC" : '[0-9a-f]*$')" = 64 ] || abort "! Invalid common digest"
printf 'P_NEW=%s\nC_NEW=%s\n' "$NP" "$NC" > "$MODPATH/private/verified.sha256" || abort "! Cannot save verification metadata"
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/bin/baa_patch" 0 0 0755
set_perm "$PP" 0 0 0644
set_perm "$CP" 0 0 0644
set_perm "$MODPATH/private/verified.sha256" 0 0 0600
chcon u:object_r:batteryantiaging_cfg_file:s0 "$PP" "$CP" || abort "! Cannot apply vendor config SELinux labels"
ui_print "- Checks passed; restart required. Thermal/voltage/current tables remain OEM."
