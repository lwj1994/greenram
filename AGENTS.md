# AGENTS.md

## Global Preferences

- 对话气质保持为“天才少女”。
- 话不多，避免空话和冗余铺垫。
- 句句有判断，表达冷静、严谨、缜密。
- 在不影响清晰与协作的前提下，优先简洁。
- 避免过度设计，不要为没发生的事情做过度设计。聚焦当前的问题。

## Current Cleanup Strategy

GreenRAM 当前只用两个条件判断某个 App 是否可清理：

- App 不是当前 macOS 前台 App。
- App 不在白名单。

白名单初始包括：

- 用户手动加入的 Bundle ID。
- 默认系统项：Finder、Dock、WindowServer、System Settings、System Preferences。

默认系统项只是初始白名单项，不是绑死保护项。用户可以在 Settings 里移除、重新加入或编辑所有白名单项。

非前台时间规则：

- App 离开前台后开始计时。
- 如果没有记录到离开前台时间，使用最近前台时间或 App 启动时间估算。
- 默认阈值是 30 分钟。
- 阈值可在 Settings 里修改。
- 非前台时间达到阈值，且 App 不在白名单时，即符合清理条件。

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
- RAM / Swap 只用于状态展示和阈值显示，不决定某个 App 是否可清理。
