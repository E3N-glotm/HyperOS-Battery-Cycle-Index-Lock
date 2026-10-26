# HyperOS Battery Cycle + SOH Index Lock · 电池循环档位与老化策略

**语言：简体中文（当前） | [English](README_EN.md)**

针对已验证的 Xiaomi `pudding` 电池硬件的 Magisk 模块。通过设备自己的原厂 BAA 加密库，有限修改电池循环次数对应的充电老化策略，不直接修改系统分区。

**当前版本：v1.4.0** · [下载 Release](https://github.com/E3N-glotm/HyperOS-Battery-Cycle-Index-Lock/releases)

> [!WARNING]
> 固定“新电池”循环分档并推迟低 SOH 降压策略，会弱化厂家针对电芯老化设计的保护，**可能加速电池衰减**。它不会提升真实电池容量，也不能替代真实充电电压、电流、温度与电芯寿命测试。

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
