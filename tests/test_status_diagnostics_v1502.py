#!/usr/bin/env python3
"""v1.5.0-alpha.2 OTA diagnostics: fail-closed classification contract.

The real hardware BAA decrypt/reencrypt round trip is validated on a physical
pudding device because redistributing proprietary OEM ciphertext or vendor
libraries is forbidden. This file checks only executed-policy invariants, and it
inspects executed statements rather than explanatory comments so that a comment
naming an operation it avoids is not mistaken for that operation.
"""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
boot = (root / "post-fs-data.sh").read_text(encoding="utf-8")
service = (root / "service.sh").read_text(encoding="utf-8")
action = (root / "action.sh").read_text(encoding="utf-8")
probe = (root / "bin/compat_probe.sh").read_text(encoding="utf-8")
prop = (root / "module.prop").read_text(encoding="utf-8")


def executed(text: str) -> str:
    """Shell lines that actually run: comments are excluded on purpose."""
    return "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))


REASONS = (
    "REASON_OEM_SOURCE_CHANGED",
    "REASON_OEM_INPUT_MISSING",
    "REASON_INTEGRITY_MISMATCH",
    "REASON_ABILITY_UNAVAILABLE",
    "REASON_NO_VALIDATED_METADATA",
    "REASON_METADATA_MALFORMED",
    "REASON_UNSUPPORTED_FORMAT",
    "REASON_OVERLAY_MUTATED",
    "REASON_SELINUX_INTERFACE_FAILURE",
    "REASON_PERMISSION_FAILURE",
    "REASON_MOUNT_FAILURE",
    "REASON_DEVICE_PROFILE_CHANGED",
)

checks = {
    "version bump keeps the immutable module id":
        "version=1.5.0-alpha.2" in prop and "versionCode=1502" in prop
        and "id=battery_cycle_aging_switch_off" in prop,
    "every documented reason code is emitted by a real code path":
        all(code in boot + service for code in REASONS),
    "status separates source change from integrity and ability failures":
        "REASON_OEM_SOURCE_CHANGED" in service
        and "REASON_INTEGRITY_MISMATCH" in service
        and "REASON_ABILITY_UNAVAILABLE" in service
        and "REASON_OEM_INPUT_MISSING" in service,
    "an inactive module never claims an effect and a mounted one is explicit":
        'state INACTIVE' in service
        and 'state ACTIVE "validated encrypted BAA pair verified' in service
        and "state STAGED" in service,
    "post-fs-data still pins both the OEM source and the generated pair":
        '"$LIVE_P" = "$P_SOURCE"' in boot and '"$LIVE_C" = "$C_SOURCE"' in boot
        and '"$LIVE_P" = "$P_NEW"' in boot and '"$LIVE_C" = "$C_NEW"' in boot,
    "mounting stays restricted to post-fs-data with symmetric rollback":
        'ns /system/bin/mount --bind "$PP" "$P"' in boot
        and 'ns /system/bin/mount --bind "$CP" "$C"' in boot
        and 'ns /system/bin/umount "$P"' in boot
        and 'ns /system/bin/umount "$C"' in boot
        and "mount --bind" not in executed(service)
        and "umount" not in executed(service),
    "an expired profile is never force-mounted on unknown firmware":
        'fail REASON_OEM_SOURCE_CHANGED' in boot
        and "--force" not in executed(boot)
        and "force-mount" not in executed(boot).replace("# force", ""),
    "both success and fallback paths leave a machine-readable audit record":
        "trap " in boot and "finalize" in boot
        and 'printf ' "state=%s" in boot.replace("'", "")
        and 'AUDIT="$MODDIR/diagnostics.txt"' in boot
        and 'AUDIT="$MODDIR/diagnostics.txt"' in service
        and "reason=%s" in boot and "reason=%s" in service,
    "unverified effects are declared instead of implied":
        "unverified=" in boot and "long_term_charging_safety" in boot
        and "unverified=" in service,
    "no firmware build-number or SDK gate was introduced":
        not any(
            marker in executed(boot + service + action + probe)
            for marker in (
                "ro.build.version.incremental=",
                "ro.build.version.sdk=",
            )
        ),
    "the probe performs no mount, label, policy or property change":
        not any(
            marker in probe
            for marker in (
                "mount --bind", "umount", "setenforce", "magiskpolicy",
                "chcon", "resetprop", "-o remount",
            )
        ),
    "the probe only prints and never writes to a file":
        ">" not in executed(probe).replace("2>/dev/null", "").replace("2>&1", ""),
    "action stays read-only and surfaces both the verdict and the audit":
        "compat_probe.sh" in action and "diagnostics.txt" in action
        and "mount --bind" not in executed(action)
        and "umount" not in executed(action)
        and "resetprop" not in executed(action)
        and "chcon" not in executed(action),
    "action states the safe fallback instead of a restored charging policy":
        "stock OEM charging policy" in action and "force-mounted" in action,
}
for label, ok in checks.items():
    if not ok:
        raise AssertionError(label)
    print("PASS", label)
print("OTA_STATUS_DIAGNOSTICS_AND_FAIL_CLOSED_CONTRACT_PASS")
