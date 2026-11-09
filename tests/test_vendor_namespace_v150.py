#!/usr/bin/env python3
"""v1.5 vendor-linker OTA compatibility: fail-closed policy regressions.

Hardware BAA decrypt/reencrypt is verified on a real pudding phone separately,
because publishing proprietary OEM encrypted data or vendor libraries is forbidden.
"""
from pathlib import Path

root=Path(__file__).resolve().parents[1]
runner=(root/"bin/baa_vendor_namespace.sh").read_text()
installer=(root/"customize.sh").read_text()
patch=(root/"src/baa_patch.cpp").read_text()
boot=(root/"post-fs-data.sh").read_text()
service=(root/"service.sh").read_text()
prop=(root/"module.prop").read_text()
checks={
    "new module version and immutable ID":
        "version=1.5.0-alpha.1" in prop
        and "versionCode=1501" in prop
        and "id=battery_cycle_aging_switch_off" in prop,
    "only vendor namespace declared by Android linker configuration":
        'CONF=/linkerconfig/ld.config.txt' in runner
        and 'BASE=/data/local/tests/vendor' in runner
        and 'grep -Fqx "dir.vendor = $BASE"' in runner,
    "private temporary executable and cleanup":
        'umask 077' in runner
        and 'mktemp -d "$BASE/e3n_baa.XXXXXXXX"' in runner
        and 'chmod 0700 "$STAGING/baa_patch"' in runner
        and 'rm -f "$STAGING/baa_patch"' in runner
        and 'rmdir "$STAGING"' in runner
        and "trap 'cleanup' EXIT" in runner,
    "no proprietary vendor libraries/files are copied to executable directory":
        'cp "$HELPER" "$STAGING/baa_patch"' in runner
        and not any(x in runner for x in (
            'cp /vendor/lib', 'cp "$SRC_P"', 'cp "$SRC_C"',
            'mount --bind', 'setenforce', 'magiskpolicy', 'chcon',
            'LD_LIBRARY_PATH=/vendor/lib64')),
    "installer invokes scoped runner, not former direct failing dlopen":
        'bin/baa_vendor_namespace.sh' in installer
        and '"$MODPATH/bin/baa_patch" "$P" "$C" "$PP" "$CP"' in installer
        and 'set_perm "$MODPATH/bin/baa_vendor_namespace.sh"' in installer,
    "installer verifies original hardware, OEM crypto ABI and source format":
        'getprop ro.product.device' in installer and 'pudding' in installer
        and '/vendor/lib64/libbaa_common.so' in installer
        and 'BAA_ENC:' in installer,
    "installer pins source and generated output hashes":
        all(x in installer for x in ("P_SOURCE=$SOURCE_P","C_SOURCE=$SOURCE_C",
                                     "P_NEW=$NP","C_NEW=$NC")),
    "reinstall from active compatible overlay supports 1.4 and 1.5":
        '1.4.*|1.5.*)' in installer,
    "post-fs-data remains strictly pinned to OEM SOURCE and generated NEW":
        'LIVE_P' in boot and 'LIVE_C' in boot
        and '"$LIVE_P" = "$P_SOURCE"' in boot
        and '"$LIVE_C" = "$C_SOURCE"' in boot
        and '"$LIVE_P" = "$P_NEW"' in boot
        and '"$LIVE_C" = "$C_NEW"' in boot
        and 'fail "OEM BAA input fingerprint changed' in boot,
    "only bounded policy targets remain 1 and >=801, SOH<=50":
        'row=json::array({{{"idx",1},{"min",1},{"max",2147483647}}});' in patch
        and 'cycle["range_min"]=801;' in patch
        and 'soh["threshold"]=50;' in patch,
    "strict non-target OEM JSON equality and crypto roundtrip remain":
        'if(reverted!=initial)' in patch
        and 'if(json::parse(crypto.decrypt(ciphertext))!=transformed)' in patch,
    "boot bind pair rolls back on second mount/attestation failure":
        'ns /system/bin/mount --bind "$PP" "$P"' in boot
        and 'ns /system/bin/mount --bind "$CP" "$C"' in boot
        and 'ns /system/bin/umount "$P"' in boot
        and 'ns /system/bin/umount "$C"' in boot,
    "service rejects mismatched mount and remains fail-closed":
        'source version/profile changed or mount integrity verification failed' in service,
}
for label, ok in checks.items():
    if not ok:
        raise AssertionError(label)
    print("PASS",label)
print("VENDOR_NAMESPACE_AND_OTA_BAA_SAFETY_CONTRACT_PASS")
