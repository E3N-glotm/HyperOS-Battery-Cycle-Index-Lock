#!/system/bin/sh
# Capability-driven HyperOS BAA_ENC installer. Physical battery profile stays
# pudding-specific; ROM build numbers and OEM ciphertext hashes are NOT gates.
ui_print "- Battery Cycle + SOH Index Lock v1.4.0 (capability detection)"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
OLD=/data/adb/modules/battery_cycle_aging_switch_off
OP="$OLD/private/BAA_config_pudding.json"
OC="$OLD/private/BAA_config_common.json"
META="$MODPATH/private/verified.sha256"
PP="$MODPATH/private/BAA_config_pudding.json"
CP="$MODPATH/private/BAA_config_common.json"
digest() { sha256sum "$1" 2>/dev/null | cut -d ' ' -f1; }
valid_sha() { [ "$(expr "$1" : '[a-f0-9]*$')" = 64 ]; }
[ "$(getprop ro.product.device)" = pudding ] || abort "! Unsupported battery hardware profile"
[ "$(getprop ro.product.cpu.abi)" = arm64-v8a ] || abort "! Requires ARM64 vendor BAA ABI"
[ -r /vendor/lib64/libbaa_common.so ] || abort "! Vendor BAA crypto capability not found"
[ -r "$P" ] && [ -r "$C" ] || abort "! BAA OEM config interfaces missing"
[ "$(head -c 8 "$P")" = BAA_ENC: ] && [ "$(head -c 8 "$C")" = BAA_ENC: ] ||
  abort "! BAA_ENC source format not supported"
[ -x /system/bin/nsenter ] || abort "! PID1 mount namespace capability unavailable"
[ -r /sys/class/xm_power/fg_master/cyclecount ] &&
[ -r /sys/class/xm_power/fg_master/soh ] || abort "! BMS cyclecount/SOH interfaces unavailable"
mkdir -p "$MODPATH/private" || abort "! Private config directory unavailable"
chmod 0700 "$MODPATH/private"
[ -x "$MODPATH/bin/baa_patch" ] || chmod 0755 "$MODPATH/bin/baa_patch"
LIVE_P="$(digest "$P")"; LIVE_C="$(digest "$C")"
valid_sha "$LIVE_P" && valid_sha "$LIVE_C" || abort "! OEM source hashes unavailable"
SOURCE_P="$LIVE_P"; SOURCE_C="$LIVE_C"
if [ -r "$OLD/module.prop" ] && [ -r "$OP" ] && [ -r "$OC" ] &&
   [ "$LIVE_P" = "$(digest "$OP")" ] && [ "$LIVE_C" = "$(digest "$OC")" ]; then
  ui_print "- Previously generated BAA_ENC pair is actively mounted"
  case "$(sed -n 's/^version=//p' "$OLD/module.prop")" in
    1.3.0)
      [ "$LIVE_P" = 21f267901bbc09981e37538749ef94275c23ffeac88e95bd44658fd02f5e8759 ] &&
      [ "$LIVE_C" = f7f41e1c649ba43ca3eee3378e75356b26de3ab54179d77f8c261688f9e9689c ] ||
        abort "! Unknown v1.3.0 hotfix provenance"
      SOURCE_P=a03abd594154588667684b8c09ceccbd51e5d9875fc827e0eee08d8d4c1ecad5
      SOURCE_C=83aac16d8bed63170c856b41b1d280e1720a2738131b5de326ae40dbcffdfd44 ;;
    1.4.*)
      [ -r "$OLD/private/verified.sha256" ] || abort "! Missing previous validation metadata"
      SOURCE_P="$(sed -n 's/^P_SOURCE=//p' "$OLD/private/verified.sha256")"
      SOURCE_C="$(sed -n 's/^C_SOURCE=//p' "$OLD/private/verified.sha256")"
      valid_sha "$SOURCE_P" && valid_sha "$SOURCE_C" || abort "! Previous source hash invalid" ;;
    *) abort "! Unknown existing BAA overlay; disable previous version and reboot" ;;
  esac
  cp "$OP" "$PP" && cp "$OC" "$CP" || abort "! Cannot migrate validated BAA overlay"
  ui_print "- Preserving verified device-generated overlay during upgrade"
else
  # Works with another HyperOS version ONLY when real vendor crypto and the
  # tested JSON safety schema both match; no incremental / SDK hard-coding.
  "$MODPATH/bin/baa_patch" "$P" "$C" "$PP" "$CP" ||
    abort "! BAA crypto or OEM JSON policy schema incompatible; stock retained"
  ui_print "- OEM capability and bounded JSON schema validated"
fi
NP="$(digest "$PP")"; NC="$(digest "$CP")"
valid_sha "$NP" && valid_sha "$NC" || abort "! Failed to hash private encrypted files"
cat > "$META" <<EOF
P_SOURCE=$SOURCE_P
C_SOURCE=$SOURCE_C
P_NEW=$NP
C_NEW=$NC
mode=validated-vendor-baa-schema
device=pudding
EOF
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/bin/baa_patch" 0 0 0755
set_perm "$PP" 0 0 0644
set_perm "$CP" 0 0 0644
set_perm "$META" 0 0 0600
chcon u:object_r:batteryantiaging_cfg_file:s0 "$PP" "$CP" ||
  abort "! OEM BAA SELinux interface incompatible"
ui_print "- Preserved all other OEM charge voltage/current/thermal tables"
ui_print "- No OS-version or fixed OEM ciphertext hash gate; reboot required"
