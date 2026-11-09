#!/system/bin/sh
# v1.5: execute the original OEM BAA crypto helper in Android's VENDOR linker
# namespace. This does NOT remount any partition, change SELinux policy,
# install any vendor library, or persist a different charging configuration.
# The caller must already have validated the pudding hardware and BAA_ENC
# source format. The native generator performs OEM schema and roundtrip checks.
#
# Android 17 linkerconfig maps executables launched under
# /data/local/tests/vendor to the vendor namespace. Under a Magisk /data/adb
# (system namespace) executable dlopen(/vendor/lib64/libbaa_common.so) may
# fail with "not accessible for the namespace (default)"; adding
# LD_LIBRARY_PATH=/vendor/lib64 instead links against incompatible system
# dependencies on this firmware. Use the scoped namespace, fail closed when
# its mapping is unavailable, and remove the temporary executable afterward.
set -eu

[ "$#" -eq 5 ] || { echo "! Expected helper plus four paths" >&2; exit 2; }
HELPER=$1
SRC_P=$2
SRC_C=$3
DST_P=$4
DST_C=$5

[ -r "$HELPER" ] || { echo "! Native helper missing" >&2; exit 3; }
[ -r "$SRC_P" ] && [ -r "$SRC_C" ] ||
    { echo "! OEM BAA inputs unavailable" >&2; exit 4; }

CONF=/linkerconfig/ld.config.txt
BASE=/data/local/tests/vendor
if [ ! -r "$CONF" ] ||
   ! grep -Fqx "dir.vendor = $BASE" "$CONF"; then
    echo "! Android vendor linker namespace mapping not available; stock retained" >&2
    exit 5
fi

# Only the private executable is staged. Never copy or ship OEM encrypted BAA
# data or vendor crypto libraries, and never modify /vendor or /odm.
umask 077
mkdir -p "$BASE" || { echo "! Vendor test namespace location unavailable" >&2; exit 6; }
[ -d "$BASE" ] && [ ! -L "$BASE" ] ||
    { echo "! Vendor namespace path type mismatch" >&2; exit 7; }

STAGING=$(mktemp -d "$BASE/e3n_baa.XXXXXXXX") ||
    { echo "! Cannot create isolated helper staging" >&2; exit 8; }
cleanup() {
    rm -f "$STAGING/baa_patch" 2>/dev/null || true
    rmdir "$STAGING" 2>/dev/null || true
}
trap 'cleanup' EXIT
trap 'exit 130' HUP INT TERM
cp "$HELPER" "$STAGING/baa_patch" ||
    { echo "! Cannot stage native helper" >&2; exit 9; }
chmod 0700 "$STAGING/baa_patch" ||
    { echo "! Cannot secure native helper" >&2; exit 10; }

# Neutralize system-namespace overrides supplied by a shell/app.
# The ELF interpreter derives the default linker namespace from the
# real executable path under dir.vendor; no system/vendor policy edits.
unset LD_LIBRARY_PATH LD_PRELOAD LD_CONFIG_FILE
"$STAGING/baa_patch" "$SRC_P" "$SRC_C" "$DST_P" "$DST_C"
rc=$?
[ "$rc" -eq 0 ] ||
    { echo "! Original OEM BAA crypto/schema validation failed; stock retained" >&2; exit "$rc"; }
exit 0
