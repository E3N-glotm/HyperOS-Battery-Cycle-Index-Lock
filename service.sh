#!/system/bin/sh
# v1.5.0-alpha.2: read-only classified status report with an append-only audit
# record. Mounting and rollback live only in post-fs-data.sh. This script
# verifies through the PID1 mount namespace and never claims an effect it cannot
# observe. A changed OEM input fingerprint is reported as an expired install
# profile with the stock OEM charging policy retained, not as a generic failure
# and not as a restored charging policy.
MODDIR=/data/adb/modules/battery_cycle_aging_switch_off
META="$MODDIR/private/verified.sha256"
STATUS="$MODDIR/status.txt"
AUDIT="$MODDIR/diagnostics.txt"
P=/odm/etc/charger/BAA_config_pudding.json
C=/odm/etc/charger/BAA_config_common.json
REASON=REASON_UNCLASSIFIED
P_SRC=absent
C_SRC=absent
P_NEW=absent
C_NEW=absent
LIVE_P=unreadable
LIVE_C=unreadable
SERVICE_STATE=not_running
digest() { sha256sum "$1" 2>/dev/null | cut -d ' ' -f 1; }
valid() { [ "$(expr "$1" : '[a-f0-9]*$')" = 64 ]; }
ns() { /system/bin/nsenter -t 1 -m -- "$@"; }
record() {
  {
    printf '\n--- service phase %s ---\n' \
      "$(/system/bin/date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo unknown)"
    printf 'phase=service\n'
    printf 'state=%s\n' "$1"
    printf 'reason=%s\n' "$REASON"
    printf 'headline=%s\n' "$2"
    printf 'verified_via=pid1_mount_namespace\n'
    printf 'live_p_sha=%s\n' "$LIVE_P"
    printf 'live_c_sha=%s\n' "$LIVE_C"
    printf 'pinned_p_source=%s\n' "$P_SRC"
    printf 'pinned_c_source=%s\n' "$C_SRC"
    printf 'pinned_p_new=%s\n' "$P_NEW"
    printf 'pinned_c_new=%s\n' "$C_NEW"
    printf 'oem_baa_service=%s\n' "$SERVICE_STATE"
    printf 'charging_policy=%s\n' "$POLICY_STATE"
    printf 'unverified=oem_service_reload;long_term_charging_safety\n'
  } >> "$AUDIT" 2>/dev/null
  if [ -f "$AUDIT" ]; then
    if [ "$(/system/bin/wc -c < "$AUDIT" 2>/dev/null || echo 0)" -gt 32768 ]; then
      /system/bin/tail -n 200 "$AUDIT" > "$AUDIT.tmp" 2>/dev/null &&
        /system/bin/mv -f "$AUDIT.tmp" "$AUDIT" 2>/dev/null
    fi
  fi
}
state() {
  POLICY_STATE=stock_unchanged
  [ "$1" = ACTIVE ] && POLICY_STATE=validated_profile_mounted_aging_protection_deferred
  [ "$1" = STAGED ] && POLICY_STATE=mount_visible_service_reload_unverified
  printf '%s: %s\n' "$1" "$2" > "$STATUS"
  /system/bin/log -p i -t BatteryAgingPolicyLock \
    "$1 $REASON $2" 2>/dev/null || true
  record "$1" "$2"
}
if [ ! -r "$META" ]; then
  REASON=REASON_NO_VALIDATED_METADATA
  state INACTIVE "no validated BAA install metadata on this boot; stock OEM configuration retained; reinstall this module to revalidate"
  exit 0
fi
P_SRC="$(sed -n 's/^P_SOURCE=//p' "$META" 2>/dev/null)"
C_SRC="$(sed -n 's/^C_SOURCE=//p' "$META" 2>/dev/null)"
P_NEW="$(sed -n 's/^P_NEW=//p' "$META" 2>/dev/null)"
C_NEW="$(sed -n 's/^C_NEW=//p' "$META" 2>/dev/null)"
if ! valid "$P_NEW" || ! valid "$C_NEW" || ! valid "$P_SRC" || ! valid "$C_SRC"; then
  REASON=REASON_METADATA_MALFORMED
  state INACTIVE "install metadata fingerprints malformed; stock OEM configuration retained; reinstall this module"
  exit 0
fi
if [ ! -x /system/bin/nsenter ]; then
  REASON=REASON_ABILITY_UNAVAILABLE
  state INACTIVE "PID1 mount namespace API unavailable so the mount result cannot be verified; stock OEM configuration retained"
  exit 0
fi
LIVE_P="$(ns /system/bin/sha256sum "$P" 2>/dev/null | cut -d ' ' -f 1)"
LIVE_C="$(ns /system/bin/sha256sum "$C" 2>/dev/null | cut -d ' ' -f 1)"
[ -z "$LIVE_P" ] && LIVE_P=unreadable
[ -z "$LIVE_C" ] && LIVE_C=unreadable
if [ "$LIVE_P" = unreadable ] || [ "$LIVE_C" = unreadable ]; then
  REASON=REASON_OEM_INPUT_MISSING
  state INACTIVE "the OEM BAA configuration interface is not readable through the PID1 namespace; stock OEM configuration retained"
  exit 0
fi
if pidof vendor.xiaomi.hardware.batteryantiaging-service >/dev/null 2>&1; then
  SERVICE_STATE="$(pidof vendor.xiaomi.hardware.batteryantiaging-service)"
fi
if [ "$LIVE_P" = "$P_NEW" ] && [ "$LIVE_C" = "$C_NEW" ]; then
  if [ "$SERVICE_STATE" != not_running ]; then
    REASON=REASON_NONE
    state ACTIVE "validated encrypted BAA pair verified in the PID1 namespace and the OEM battery antiaging service is running; aging-related charging reductions are intentionally deferred"
  else
    REASON=REASON_SERVICE_NOT_RUNNING
    state STAGED "validated encrypted BAA pair is what the OEM namespace reads, but the OEM battery antiaging service is not running; the charging effect is unverified"
  fi
  exit 0
fi
if [ "$LIVE_P" = "$P_SRC" ] && [ "$LIVE_C" = "$C_SRC" ]; then
  REASON=REASON_INTEGRITY_MISMATCH
  state INACTIVE "OEM input still matches the pinned source but the OEM namespace does not read the validated pair; mount integrity verification failed; stock OEM configuration retained"
  exit 0
fi
REASON=REASON_OEM_SOURCE_CHANGED
state INACTIVE "OEM BAA input fingerprint changed after a firmware update, so this install profile is expired for the running firmware; nothing was force-mounted and the stock OEM charging policy of the new firmware remains in effect; reinstall to revalidate on this firmware"
