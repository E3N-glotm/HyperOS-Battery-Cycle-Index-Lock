# HyperOS Battery Cycle + SOH Index Lock

## v1.4.0: 按实际接口兼容 / Capability detection

- 不按 Android SDK 或 HyperOS 小版本号判断；需要 **pudding 电池硬件配置**、原厂 `BAA_ENC` 文件、同 ABI 的 `libbaa_common.so` 解密/加密符号、BMS 循环次数/SOH 节点和通过验证的原厂 JSON 策略结构。
- 安装时在本机重新生成两份加密文件，先进行完整的结构化差异和回解密一致性校验；仅修改 CN/GL cycle index 与两份 LowSoh 门槛，不直接写 OEM 分区。
- **升级后源文件内容发生变化时将停止挂载旧配置**。在新 ROM 上重新安装 v1.4.0 后才能重新检测和生成。接口存在但策略字段结构不符合安全断言时仍会拒绝启用。
- 保留 `pudding` 设备/电芯配置限制，因为充电电压表不能只凭路径存在就视作其他机型安全。此项修改不会使电池恢复健康度，可能弱化原厂老化保护。


[中文](#中文) · [English](#english) · [Releases](https://github.com/E3N-glotm/HyperOS-Battery-Cycle-Index-Lock/releases)

## 中文

### v1.3.0 — HyperOS 4 / Android 17

**仅支持** Xiaomi `pudding`、`OS4.0.4.0.XPCCNXM`、Android 17（API 37）及下面锁定的原厂电池配置。不是通用充电增强模块。

本模块将原厂 `BasedOnCC-VolDown` 的 CN/GL 电池循环次数映射固定到 `cyclecount_index=1`，并把**机型配置和通用配置**的 `LowSoh-FvDown` 修改为仅在循环次数至少 801 次、原始 SOH 不高于 50 时触发；以上两个 LowSoh 条件必须同时满足。

修改严格限于五条 JSON 字段路径：两套 `cyclecount_index_map`，以及机型和通用文件各三项 LowSoh 阈值字段（合计八处字段或子树变化）。保持原厂每个充电温度区间、电压表、充电电流阶梯、`FreqChg-FvDown`、`ChargerModeProtect` 不变；不修改真实循环次数、BMS SOH、FCC，也不关闭内核/PMIC 过流、过压或温控保护。

**HyperOS 4 改用 `BAA_ENC:` 加密文件。** v1.3.0 Release ZIP **不包含任何从设备复制的原厂加密配置、明文电池参数或加密密钥**，而是在安装时使用手机自己的 `/vendor/lib64/libbaa_common.so` 完成解密、有限 JSON 修改、重新加密与解密回读验证。构建程序只包含通用逻辑，JSON 解析器使用 MIT 许可的 [nlohmann/json](https://github.com/nlohmann/json)。两个私有加密配置仅写入本机 Magisk 模块目录。

版本与哈希校验：

| 项目 | 仅允许的值 |
| --- | --- |
| 设备 | pudding |
| ROM | OS4.0.4.0.XPCCNXM |
| SDK | 37 |
| 原厂 pudding BAA SHA-256 | `a03abd594154588667684b8c09ceccbd51e5d9875fc827e0eee08d8d4c1ecad5` |
| 原厂 common BAA SHA-256 | `83aac16d8bed63170c856b41b1d280e1720a2738131b5de326ae40dbcffdfd44` |

支持从**已验证的此设备 v1.3.0 热修复版本**原位迁移；遇到其他 ROM、加密配置哈希或未经确认的预先修改配置时直接停止安装（fail closed），不会猜测新的安全电压或修改系统分区。

### 安装、状态和恢复

在 Magisk 中选择本仓库 Release 下 `HyperOS-Battery-Cycle-Index-Lock-v1.3.0.zip`，安装并重启。点击模块的“操作”按钮可读取状态、真实循环计数、原始 SOH、UI SOH、实际挂载配置 SHA-256 和原厂抗老化进程 PID。

启动脚本在 PID 1 mount namespace 对两份配置执行 systemless bind mount；挂载后用安装时生成的 SHA-256 重新检查。任一校验失败则不继续套用未知配置，且尝试回滚部分挂载。停用/卸载模块后重启，恢复原厂配置与原厂循环分档，不会对 ODM/Vendor 做持久写入。

原厂默认循环档位是 1–100→1、101–300→2、301–800→3、801+→4。固定 `index=1` 后，随电芯实际循环增加，将丧失这项分档降压保护。**这可能加快高 SOC、高电压或高温下的电池老化，不会令旧电池重新变新。** LowSoh 的触发被延后也会弱化厂家设计的寿命策略，请在充分理解风险的情况下使用。

**实机测试（2026-10-19）：** OS4.0.4.0 / API37；原始循环次数 112，raw SOH=96，UI SOH=99。v1.3.0 热修复版本中两份 BAA_ENC 文件冷启动挂载成功，原厂 `batteryantiaging` 服务运行，开机挂载文件可以通过原厂库解密并验证。新版自动生成器对两份原厂备份文件完成了真实设备的加密往返测试。未完成各温度档的真实充电曲线与长期老化验证，因此不应把软件加载测试解释为电芯安全测试。

HyperOS 3 / Android 16 的旧版用户请使用 [v1.2.0](https://github.com/E3N-glotm/HyperOS-Battery-Cycle-Index-Lock/releases/tag/v1.2.0)，**不要交叉安装**。

## English

### v1.3.0 — HyperOS 4 / Android 17 only

For **Xiaomi pudding**, exact firmware **OS4.0.4.0.XPCCNXM**, Android **API 37**, with exact pinned stock configuration SHA-256 values shown above.

- Pin `BasedOnCC-VolDown` cycle index to **1** for both CN and GL battery maps.
- Set the `LowSoh-FvDown` criteria in **both** common and device JSON to **cycle count >= 801 AND raw SOH <= 50**.
- Preserve all OEM current, voltage, temperature, frequency-charging, and charger-mode protection tables. Never spoof cycle count, BMS SOH or FCC.
- The ZIP contains **no proprietary OEM config, encryption keys, or device data**. On install, it decrypts and re-encrypts each original `BAA_ENC:` configuration using the device's vendor library and validates the JSON semantic changes and encryption roundtrip.
- Exact model, ROM, API and OEM input file hash verification; fail closed for unknown versions.
- Restore by disabling/uninstalling and **rebooting**.

**Risk:** keeping a new-battery profile at elevated cycle counts and deferring low-SOH voltage reductions may accelerate battery aging. No real-world charging voltage/current cycle test has yet been completed.

For HyperOS 3 / Android 16 use the existing [v1.2.0](https://github.com/E3N-glotm/HyperOS-Battery-Cycle-Index-Lock/releases/tag/v1.2.0).

## Source & licenses

- Module source: MIT License, by E3N.
- Vendor cryptography: dynamically loaded from the end user's firmware, never shipped in the module.
- JSON implementation: [nlohmann/json](https://github.com/nlohmann/json), MIT License.
- Magisk ZIP SHA-256 is published in each Release's notes.
