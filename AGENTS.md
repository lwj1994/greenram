# AGENTS.md

## Global Preferences

- 对话气质保持为“天才少女”。
- 话不多，避免空话和冗余铺垫。
- 句句有判断，表达冷静、严谨、缜密。
- 在不影响清晰与协作的前提下，优先简洁。
- 避免过度设计，不要为没发生的事情做过度设计。聚焦当前的问题。

## Current Cleanup Strategy

GreenRAM 当前按三组规则判断某个 App 是否可清理：

- 白名单 App 永不清理。
- Auto-Quit Apps 只验证非前台时间。
- 普通 App 必须同时满足非前台时间达标，以及系统内存状态超限或该 App 达到自己的单 App 内存上限。

白名单初始包括：

- 用户手动加入的 Bundle ID。
- 默认系统项：Finder、Dock、WindowServer、System Settings、System Preferences。

默认系统项只是初始白名单项，不是绑死保护项。用户可以在 Settings 里移除、重新加入或编辑所有白名单项。只要仍在白名单中，就永久不清理。

非前台时间规则：

- App 离开前台后开始计时。
- 如果没有记录到离开前台时间，使用最近前台时间或 App 启动时间估算。
- 所有 App 默认使用全局阈值，默认是 30 分钟。
- 单 App 时间覆盖只改变该 Bundle ID 的非前台时间阈值。
- 单 App 时间覆盖不会让 App 变成 Auto-Quit App。
- Auto-Quit 身份由 Auto-Quit Apps 列表单独决定。
- 默认阈值和单 App 时间覆盖都可在 Settings 里修改。
- Auto-Quit Apps 非前台时间达到阈值，且不在白名单时，即符合清理条件。
- 普通 App 非前台时间达到自身阈值，且系统内存状态超限或该 App 达到自己的单 App 内存上限，且不在白名单时，才符合清理条件。
- 白名单 App 不能添加 Auto-Quit、单 App 时间覆盖、单 App 内存上限；必须先从白名单移除。
- 将 App 加入白名单时，会移除 Auto-Quit 身份。
- 单 App 时间覆盖和单 App 内存上限会保留配置，但白名单期间不生效。

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
- 未配置单 App 内存上限时，单个 App 的内存大小不决定它是否可清理。
- RAM / Swap 状态超限作为普通 App 的系统级清理 gate；单 App 内存上限作为普通 App 的 App 级清理 gate；Auto-Quit Apps 不等待任何内存 gate。

## Idle Child Process Cleanup

闲置子进程清理独立于上面三组 App 规则，只结束 App 进程树里的外部子进程，不退出 App：

- 外部子进程：可执行文件不在任何 `.app` bundle 内，且不挂在终端上。App 自己的 helper 和终端交互任务不参与。
- 清理单位是子进程组：父进程不是外部进程的那个外部进程，连同全部子孙。只整组清理。
  - 不单杀组内深层进程：例如只杀 dart analyzer，`dart mcp-server` 不会重启它，之后 analyze_files 静默返回 "No errors"。整组杀掉后由上层（如 Claude Code）按需重启。
- 整组闲置 30 分钟以上（期间 CPU 时间增长不足 3 秒），且合计内存达到 100 MB 才清理。
- 前台 App 的子进程不清理。白名单只保护 App 不被退出，不阻止子进程清理。
- 先 SIGTERM，5 秒后 SIGKILL；发信号前用进程启动时间排除 pid 复用。每个子进程组只尝试一次。
- 每个被清理的组记一条事件：所属 App、进程数、内存、闲置时长、每个进程的命令名和 PID。
