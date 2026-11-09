# HyperOS Battery Cycle + SOH Index Lock · 电池循环档位与老化策略

**语言：简体中文（当前） | [English](README_EN.md)**

针对已验证的 Xiaomi `pudding` 电池硬件的 Magisk 模块。通过设备自己的原厂 BAA 加密库，有限修改电池循环次数对应的充电老化策略，不直接修改系统分区。

**当前版本：v1.5.0-alpha.1（固件适配预览版）** · [下载 Release](https://github.com/E3N-glotm/HyperOS-Battery-Cycle-Index-Lock/releases)

> [!WARNING]
> 固定“新电池”循环分档并推迟低 SOH 降压策略，会弱化厂家针对电芯老化设计的保护，**可能加速电池衰减**。它不会提升真实电池容量，也不能替代真实充电电压、电流、温度与电芯寿命测试。

## v1.5.0-alpha.1：HyperOS 4.0.5 原厂 BAA 加密库兼容修复

**[新版本 Release](https://github.com/E3N-glotm/HyperOS-Battery-Cycle-Index-Lock/releases/tag/v1.5.0-alpha.1)**（预览版，不作为稳定 Latest）。

在实测 `pudding / OS4.0.5.0.XPCCNXM` 固件中，两份原厂 BAA_ENC 配置的 SHA-256 相对于 v1.4.0 安装时发生变化，原模块严格拒绝旧配置挂载，显示 `INACTIVE`。直接使用旧版本二进制生成新配置又因 Android 17 linker 的默认命名空间限制而无法 `dlopen("/vendor/lib64/libbaa_common.so")`；仅设置 `LD_LIBRARY_PATH=/vendor/lib64` 会造成系统/厂商依赖混用，不能作为修复。

新版本经真机验证：安装阶段确认系统 `/linkerconfig/ld.config.txt` 中存在 `dir.vendor = /data/local/tests/vendor` 映射后，将**模块原有的、未经修改的** BAA 本机验证器临时复制到该目录下唯一私有子目录执行，用当前设备自己的原厂库解密、按照原 v1.4.0 严格 JSON 结构验证和指定字段修改后重新加密回读，两个输出都完成校验。临时可执行文件随即清理，不复制原厂库，不修改厂商分区、不关闭 SELinux。如果不具备相同链接命名空间映射或原厂 JSON 规则变化，则**停止安装、不覆盖原厂配置**。

原有目标**完全不变**：CN/GL 循环档位仅保留 `cyclecount_index=1`，`LowSoh-FvDown` 只在循环次数≥801且**原始 SOH≤50**时触发，其他 OEM 充电电压、充电电流、温控、真实循环次数和电芯 SOH 全部保留。与 v1.4.0 相比，`src/baa_patch.cpp`、`post-fs-data.sh` 和 `service.sh` 均不更改；启动时仍对比本次安装记录的两份原厂源指纹及新配置指纹，任一项失配即安全停用，双文件挂载失败会回滚。

**注意：这是有意推迟厂家充电老化降压保护的实验模块，不会让电池恢复新电池状态，可能增加老化、发热或充电安全风险。** 当前固件已完成原厂配置重新生成的离线式验证，但尚未通过下次重启后的原厂服务加载和长期充电数据验收。安装 ZIP 后需要正常重启，才能由原有安全开机流程挂载，不得在运行中强行跳过指纹保护。

## 实际修改范围

- 将 `BasedOnCC-VolDown` 中 **CN 和 GL** 两套 `cyclecount_index_map` 固定为 `cyclecount_index=1`。
- 机型配置和通用配置里的 `LowSoh-FvDown` 只有在**循环次数 ≥ 801 且原始 SOH ≤ 50** 同时满足时才触发。
- 保留原厂充电温度区间、充电电流/电压表、`FreqChg-FvDown`、`ChargerModeProtect`、真实 BMS SOH 和循环计数。
- 系统原有的内核与 PMIC 保护仍由厂商实现；该模块并不能保证绕开老化管理后的长期安全性。

## 兼容性与加密配置

**v1.4.0 不再依赖固定 ROM 名称、Android SDK 号或单一原厂密文 SHA 白名单。** 安装时同时检查 `pudding` 硬件身份、`BAA_ENC:` 文件格式、厂商 `/vendor/lib64/libbaa_common.so` 的 ABI、BMS 节点以及原厂 JSON 策略结构。只有匹配并能通过严格的差异与加解密往返校验，才生成覆盖文件。

设备升级后若原厂 BAA 源内容改变，开机会**拒绝继续挂载旧配置**，必须重新安装最新版并重新探测。其他机型即使路径相同，也不能假设电芯/电压表兼容。

## 安装与回退

1. 从 [Releases](https://github.com/E3N-glotm/HyperOS-Battery-Cycle-Index-Lock/releases) 安装 `v1.4.0` 或更新的 Magisk ZIP，重启。
2. 在模块的“操作”入口检查 `ACTIVE`、原厂 BAA 服务、两份加密覆盖文件和原始 SOH、循环次数信息。
3. 若兼容检测失败，**不要强制替换 OEM 配置文件**；仅在确认新版厂商接口匹配后再尝试。
4. 禁用/卸载并重启，恢复原厂策略；ZIP 不包含原厂加密配置、密钥或用户电池数据。

## 测试边界

已验证设备上的安装与冷启动挂载，并非经过长周期真实充电曲线与寿命验证。旧 v1.2/v1.3 的固定版本限制只对应历史安装器；当前版本以实际接口校验为准。版权、JSON 库及原厂加密数据处理见 [英文文档](README_EN.md)。
