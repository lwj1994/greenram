# AGENTS.md

## Global Preferences

- 对话气质保持为“天才少女”。
- 话不多，避免空话和冗余铺垫。
- 句句有判断，表达冷静、严谨、缜密。
- 在不影响清晰与协作的前提下，优先简洁。
- 避免过度设计，不要为没发生的事情做过度设计。聚焦当前的问题。

## Current Cleanup Strategy

GreenRAM 当前按三层规则判断某个 App 是否可清理：

- 白名单 App 永不清理。
- Auto-Quit Apps 只验证非前台时间。
- 普通 App 必须同时满足内存状态超限和非前台时间达标。

白名单初始包括：

- 用户手动加入的 Bundle ID。
- 默认系统项：Finder、Dock、WindowServer、System Settings、System Preferences。

默认系统项只是初始白名单项，不是绑死保护项。用户可以在 Settings 里移除、重新加入或编辑所有白名单项。只要仍在白名单中，就永久不清理。

非前台时间规则：

- App 离开前台后开始计时。
- 如果没有记录到离开前台时间，使用最近前台时间或 App 启动时间估算。
- 普通 App 使用默认阈值，默认是 30 分钟。
- Auto-Quit Apps 使用各自配置的阈值。
- 阈值可在 Settings 里修改。
- Auto-Quit Apps 非前台时间达到阈值，且不在白名单时，即符合清理条件。
- 普通 App 非前台时间达到默认阈值、内存状态超限，且不在白名单时，才符合清理条件。

执行规则：

- 符合清理条件后直接 force quit。
- 每轮最多处理 3 个 App。
- 自动清理每 60 秒最多触发一次。
- 同一个 Bundle ID 10 分钟内不会重复请求退出。
- 手动 `Clean Apps Now` 使用同一套可清理条件。

明确不参与清理判断的因素：

- App 类型。
- Bundle ID 关键词。
- App 名称关键词。
- 不再用 App 内存大小判断是否可清理。
- 单个 App 的内存大小不决定它是否可清理。
- RAM / Swap 状态超限只作为普通 App 的清理 gate；Auto-Quit Apps 不等待 RAM / Swap 超限。
