# HyperOS Battery Cycle Index Lock

[中文](#中文) | [English](#english)

A small Magisk module for a specific Xiaomi HyperOS build that keeps Xiaomi's `BasedOnCC-VolDown` cycle-count charging profile permanently on `cyclecount_index = 1`.

> Tested target: `pudding` / `OS3.0.319.0.WPCCNXM` / Android 16 (SDK 36)

## 中文

### 作用

这台设备的原厂 `BAA_config_pudding.json` 会按照电池循环次数切换 `BasedOnCC-VolDown` 充电档位：

| 循环次数 | 原厂 cyclecount_index |
|---|---:|
| 1–100 | 1 |
| 101–300 | 2 |
| 301–800 | 3 |
| 801+ | 4 |

本模块将 CN/GL 两套电池配置中的 `cyclecount_index_map` 改为：

```json
[
  {"idx": 1, "min": 1, "max": 2147483647}
]
```

因此无论实际循环次数是多少，`BasedOnCC-VolDown` 都只会选择 index 1，也就是原厂 1–100 次循环使用的那套充电参数。

### 它没有做什么

本模块**不会**：

- 修改、伪造或清零真实循环次数；
- 修改 BMS 的 SOH、Qmax、FCC 等健康状态；
- 禁用 `LowSoh-FvDown` 或 `FreqChg-FvDown`；
- 禁用温度、过压、过流、PMIC 或内核最终保护；
- 永久写入 `/odm`、`/vendor` 或系统分区。

所以它只把“按循环次数切换 index 1/2/3/4”这一维固定为 index 1，并不把旧电池伪装成真正的新电池。

### 当前实机验证

在测试机上：

- 实际循环次数：`101`
- 模块状态：`ACTIVE`
- live `/odm/etc/charger/BAA_config_pudding.json` 已通过 systemless bind mount 生效；
- CN 与 GL 两套 `cyclecount_index_map` 均只有：
  `idx=1, min=1, max=2147483647`
- `batteryantiaging` 服务正常运行；
- `smart_fv=0`、`smart_batt=0`、`smart_chg=0`、`smart_night=0`，检查时没有其它智能降压叠加。

index 1 的原厂主要终止电压仍保持原值，例如 CN 电池：

- FFC：约 `4.570 V`
- normal（23–35°C）：约 `4.520 V`

因此**就循环次数分档这一项而言，101 次循环时使用的逻辑与新机 1–100 次档一致**。但真实 BMS 状态、温度以及其它保护仍按当前电池实际状态工作。

### 安装

1. 使用 Magisk 安装 Release 中的 ZIP。
2. 重启。
3. 在 Magisk 模块页面点击模块操作按钮，可查看当前状态和 live map。

模块安装时会：

- 校验设备为 `pudding`；
- 校验 ROM 为 `OS3.0.319.0.WPCCNXM`；
- 校验原厂 `BAA_config_pudding.json` 的 SHA-256；
- 从设备自身原厂配置生成 patched 文件；
- 开机早期使用 bind mount 覆盖 live 路径。

若 ROM/文件 hash 不匹配，模块会 fail closed，不应用旧补丁。

### 卸载/恢复

在 Magisk 中禁用或卸载模块，然后重启即可恢复原厂：

- 1–100 → index 1
- 101–300 → index 2
- 301–800 → index 3
- 801+ → index 4

### 风险说明

固定使用较高的原厂 index 1 充电终止电压，会削弱 Xiaomi 针对高循环次数设计的寿命保护策略，长期使用可能增加高 SOC/高电压下的电池老化速度。请自行承担电池寿命与安全风险。

本模块没有绕过 PMIC/内核级硬件保护，但这不等于“没有风险”。

## English

### What it does

The stock `BAA_config_pudding.json` selects Xiaomi's `BasedOnCC-VolDown` charging profile by battery cycle count:

| Cycle count | Stock cyclecount_index |
|---|---:|
| 1–100 | 1 |
| 101–300 | 2 |
| 301–800 | 3 |
| 801+ | 4 |

This module changes both CN and GL battery maps to:

```json
[
  {"idx": 1, "min": 1, "max": 2147483647}
]
```

So every real cycle count resolves to `cyclecount_index = 1`, i.e. the OEM charging parameter set normally used for cycles 1–100.

### What it does not do

It does **not**:

- fake, reset, or modify the real cycle count;
- overwrite BMS SOH, Qmax, FCC, or health-learning data;
- disable `LowSoh-FvDown` or `FreqChg-FvDown`;
- disable thermal, over-voltage, over-current, PMIC, or kernel final protection;
- permanently modify `/odm`, `/vendor`, or system partitions.

It only locks the cycle-count profile selection to index 1. It does not make an aged battery electrically equivalent to a new battery.

### Verified behavior

On the tested device:

- real cycle count: `101`
- module state: `ACTIVE`
- the live ODM config is systemlessly bind-mounted;
- both CN and GL maps contain only `idx=1, min=1, max=2147483647`;
- Xiaomi `batteryantiaging` service remains running;
- `smart_fv`, `smart_batt`, `smart_chg`, and `smart_night` were all `0` during verification.

For the CN battery, the OEM index-1 termination values remain unchanged, including approximately:

- FFC: `4.570 V`
- normal charging at 23–35°C: `4.520 V`

Therefore, **for the cycle-count branch specifically, a 101-cycle battery follows the same index-1 profile used by a fresh 1–100-cycle battery**. Other real battery state and protection logic still apply.

### Installation

1. Install the ZIP from Releases in Magisk.
2. Reboot.
3. Use the module action button in Magisk to inspect current status and the live cycle map.

The installer checks the exact device, ROM build, and stock config SHA-256 before generating the patched config. Mismatches fail closed.

### Restore stock behavior

Disable or uninstall the module in Magisk and reboot.

### Warning

Keeping the higher OEM index-1 termination voltage after the battery has accumulated more cycles intentionally weakens Xiaomi's cycle-count anti-aging policy. Long-term use may accelerate battery aging under high-SOC/high-voltage conditions.

The module retains hardware-level protections, but that does not make the modification risk-free.

## Release

`v1.1.0`

Release ZIP SHA-256:

```text
2457c678b4fcf9c29a5b656dbe06867734f11ecb5ab28e0a9157e9bc4298ea6b
```

## License

MIT
