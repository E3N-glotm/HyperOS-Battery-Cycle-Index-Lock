# Battery Cycle + SOH Index Lock — English reference

**Language: [简体中文](README.md) | English (current)**

**Current version: v1.4.0 — feature-based installation.** The module no longer gates on an exact ROM build, SDK number or a hardcoded source ciphertext hash. Instead it verifies Xiaomi `pudding` battery hardware, the `BAA_ENC:` vendor crypto API, BMS cycle/SOH nodes and the complete relevant OEM JSON schema. The original OEM configuration fingerprint is recorded during install. After an OTA changes that source, the previous overlay is not mounted, and the module must be reinstalled to regenerate it. Do not use on other battery hardware even if paths appear similar.

**Behavior:** CN and GL cycle mappings are held at `index=1`; low-SOH FV reduction in both common/device configs requires **cycle count >= 801 AND raw SOH <= 50**. The module preserves other charging/thermal tables, but can weaken battery-aging protection and accelerate wear. No charging-curve safety study has been completed. Historical v1.3.0-specific conditions below are reference only.


## Historical behavior (v1.3.0)

For **Xiaomi pudding**, exact firmware **OS4.0.4.0.XPCCNXM**, Android **API 37**, with exact pinned stock configuration SHA-256 values shown above.

- Pin `BasedOnCC-VolDown` cycle index to **1** for both CN and GL battery maps.
- Set the `LowSoh-FvDown` criteria in **both** common and device JSON to **cycle count >= 801 AND raw SOH <= 50**.
- Preserve all OEM current, voltage, temperature, frequency-charging, and charger-mode protection tables. Never spoof cycle count, BMS SOH or FCC.
- The ZIP contains **no proprietary OEM config, encryption keys, or device data**. On install, it decrypts and re-encrypts each original `BAA_ENC:` configuration using the device's vendor library and validates the JSON semantic changes and encryption roundtrip.
- On v1.4.0, validated vendor interfaces and OEM JSON structure replace the old firmware-string and hardcoded hash gate. OTA source changes fail closed until reinstall.
- Restore by disabling/uninstalling and **rebooting**.

**Risk:** keeping a new-battery profile at elevated cycle counts and deferring low-SOH voltage reductions may accelerate battery aging. No real-world charging voltage/current cycle test has yet been completed.

For HyperOS 3 / Android 16 use the existing [v1.2.0](https://github.com/E3N-glotm/HyperOS-Battery-Cycle-Index-Lock/releases/tag/v1.2.0).

## Source & licenses

- Module source: MIT License, by E3N.
- Vendor cryptography: dynamically loaded from the end user's firmware, never shipped in the module.
- JSON implementation: [nlohmann/json](https://github.com/nlohmann/json), MIT License.
- Magisk ZIP SHA-256 is published in each Release's notes.
