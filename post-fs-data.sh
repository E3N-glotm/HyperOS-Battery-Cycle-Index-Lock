#!/system/bin/sh
# v1.5.0-alpha.2: the fail-closed mounting decision is identical to
# v1.5.0-alpha.1; only the diagnostics changed. This is the only script allowed
# to bind-mount, and only after the installer-pinned encrypted pair is re-hashed
# through the PID1 mount namespace. When the OEM input fingerprint no longer
# matches what was validated at install time, that profile is treated as
# expired: nothing is force-mounted, the running firmware's stock OEM charging
# policy stays authoritative, and the precise reason is recorded instead of
# collapsed into one generic sentence.
MODDIR=/data/adb/modules/battery_cycle_aging_switch_off
STATUS="$MODDIR/status.txt"
AUDIT="$MODDIR/diagnostics.txt"
AUDIT_TMP="$MODDIR/.diagnostics.tmp"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
PP="$MODDIR/private/BAA_config_pudding.json"
CP="$MODDIR/private/BAA_config_common.json"
META="$MODDIR/private/verified.sha256"
STATE=INACTIVE
REASON=REASON_UNCLASSIFIED
MOUNT_STATE=not_mounted
POLICY_STATE=stock_unchanged
HEADLINE="boot audit did not complete; stock OEM configuration retained"
LIVE_P=unreadable
LIVE_C=unreadable
digest() { sha256sum "$1" 2>/dev/null | cut -d ' ' -f 1; }
valid() { [ "$(expr "$1" : '[a-f0-9]*$')" = 64 ]; }
ns() { /system/bin/nsenter -t 1 -m -- "$@"; }
finalize() {
  PS="$(sed -n 's/^P_SOURCE=//p' "$META" 2>/dev/null)"
  CS="$(sed -n 's/^C_SOURCE=//p' "$META" 2>/dev/null)"
  PN="$(sed -n 's/^P_NEW=//p' "$META" 2>/dev/null)"
  CN="$(sed -n 's/^C_NEW=//p' "$META" 2>/dev/null)"
  {
    printf 'timestamp=%s\n' \
      "$(/system/bin/date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo unknown)"
    printf 'phase=post-fs-data\n'
    printf 'module_version=%s\n' \
      "$(sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null || echo unknown)"
    printf 'device=%s\n' "$(getprop ro.product.device)"
    printf 'oem_build=%s\n' "$(getprop ro.build.version.incremental)"
    printf 'pinned_p_source=%s\n' "${PS:-absent}"
    printf 'pinned_c_source=%s\n' "${CS:-absent}"
    printf 'pinned_p_new=%s\n' "${PN:-absent}"
    printf 'pinned_c_new=%s\n' "${CN:-absent}"
    printf 'live_p_sha=%s\n' "$LIVE_P"
    printf 'live_c_sha=%s\n' "$LIVE_C"
    printf 'mount_state=%s\n' "$MOUNT_STATE"
    printf 'oem_baa_service=%s\n' \
      "$(pidof vendor.xiaomi.hardware.batteryantiaging-service 2>/dev/null || echo not_running)"
    printf 'charging_policy=%s\n' "$POLICY_STATE"
    printf 'state=%s\n' "$STATE"
    printf 'reason=%s\n' "$REASON"
    printf 'headline=%s\n' "$HEADLINE"
    printf 'unverified=oem_service_reload;long_term_charging_safety\n'
  } > "$AUDIT_TMP" 2>/dev/null
  if [ -s "$AUDIT_TMP" ]; then
    mv -f "$AUDIT_TMP" "$AUDIT" 2>/dev/null || printf '%s\n' "audit write failed" > "$STATUS"
  fi
  rm -f "$AUDIT_TMP"
  printf '%s: %s\n' "$STATE" "$HEADLINE" > "$STATUS"
  /system/bin/log -p i -t BatteryAgingPolicyLock \
    "$STATE $REASON $HEADLINE" 2>/dev/null || true
}
fail() {
  STATE=INACTIVE
  REASON="$1"
  shift
  HEADLINE="$*; stock OEM configuration retained"
  exit 0
}
trap 'finalize' EXIT
rm -f "$AUDIT_TMP"
[ "$(getprop ro.product.device)" = pudding ] || fail "device hardware profile changed"
[ "$(getprop ro.product.device)" = pudding ] ||
  fail REASON_DEVICE_PROFILE_CHANGED "device hardware profile changed"
[ -x /system/bin/nsenter ] || fail REASON_ABILITY_UNAVAILABLE "PID1 mount API unavailable"
[ -r /vendor/lib64/libbaa_common.so ] ||
  fail REASON_ABILITY_UNAVAILABLE "OEM BAA decoder ABI absent"
[ -r "$META" ] || fail REASON_NO_VALIDATED_METADATA "installer validation metadata missing"
P_SOURCE="$(sed -n 's/^P_SOURCE=//p' "$META")"
C_SOURCE="$(sed -n 's/^C_SOURCE=//p' "$META")"
P_NEW="$(sed -n 's/^P_NEW=//p' "$META")"
C_NEW="$(sed -n 's/^C_NEW=//p' "$META")"
for sha in "$P_SOURCE" "$C_SOURCE" "$P_NEW" "$C_NEW"; do
  valid "$sha" || fail REASON_METADATA_MALFORMED "invalid installer SHA metadata"
done
for f in "$P" "$C" "$PP" "$CP"; do
  [ -r "$f" ] || fail REASON_OEM_INPUT_MISSING "missing $f"
  [ "$(head -c 8 "$f")" = BAA_ENC: ] ||
    fail REASON_UNSUPPORTED_FORMAT "unsupported BAA format $f"
done
[ "$(digest "$PP")" = "$P_NEW" ] && [ "$(digest "$CP")" = "$C_NEW" ] ||
  fail REASON_OVERLAY_MUTATED "private encrypted BAA overlay mutated"
LIVE_P="$(ns /system/bin/sha256sum "$P" 2>/dev/null | cut -d ' ' -f 1)"
LIVE_C="$(ns /system/bin/sha256sum "$C" 2>/dev/null | cut -d ' ' -f 1)"
[ -z "$LIVE_P" ] && LIVE_P=unreadable
[ -z "$LIVE_C" ] && LIVE_C=unreadable
if [ "$LIVE_P" = "$P_NEW" ] && [ "$LIVE_C" = "$C_NEW" ]; then
  MOUNT_STATE=verified_active
  POLICY_STATE=validated_profile_mounted_aging_protection_deferred
  STATE=MOUNTED
  REASON=REASON_NONE
  HEADLINE="verified encrypted BAA pair already active in the PID1 namespace"
  exit 0
fi
# Detect changes in source after OTA, not Android build version changes.
[ "$LIVE_P" = "$P_SOURCE" ] && [ "$LIVE_C" = "$C_SOURCE" ] ||
  fail REASON_OEM_SOURCE_CHANGED \
    "OEM BAA input fingerprint changed; this install profile is expired for the running firmware, reinstall to revalidate"
chown 0:0 "$PP" "$CP" ||
  fail REASON_PERMISSION_FAILURE "could not set ownership on the private encrypted pair"
chmod 0644 "$PP" "$CP" ||
  fail REASON_PERMISSION_FAILURE "could not set mode on the private encrypted pair"
chcon u:object_r:batteryantiaging_cfg_file:s0 "$PP" "$CP" ||
  fail REASON_SELINUX_INTERFACE_FAILURE "OEM BAA label interface rejected the private pair"
ns /system/bin/mount --bind "$PP" "$P" || fail REASON_MOUNT_FAILURE "pudding bind failed"
MOUNT_STATE=partial
if ! ns /system/bin/mount --bind "$CP" "$C"; then
  ns /system/bin/umount "$P" 2>/dev/null
  MOUNT_STATE=rolled_back
  fail REASON_MOUNT_FAILURE "common bind failed; rolled back"
fi
if [ "$(ns /system/bin/sha256sum "$P" 2>/dev/null | cut -d ' ' -f 1)" != "$P_NEW" ] ||
   [ "$(ns /system/bin/sha256sum "$C" 2>/dev/null | cut -d ' ' -f 1)" != "$C_NEW" ]; then
  ns /system/bin/umount "$C" 2>/dev/null
  ns /system/bin/umount "$P" 2>/dev/null
  MOUNT_STATE=rolled_back
  fail REASON_INTEGRITY_MISMATCH "active encrypted BAA hashes differ; rolled back"
fi
MOUNT_STATE=verified_active
POLICY_STATE=validated_profile_mounted_aging_protection_deferred
STATE=MOUNTED
REASON=REASON_NONE
HEADLINE="BAA_ENC OEM schema mounted; CN/GL index1; LowSoh cycles>=801 raw SOH<=50"
