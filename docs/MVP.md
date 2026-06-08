# MVP 功能梳理

## 第一部分：内存压力释放

目标：自动退出长时间不在前台、且不在白名单里的可清理 App。

已实现：

- 菜单栏常驻。
- 监听前台 App 切换。
- 枚举 Regular GUI App。
- 采样 App memory footprint，并聚合它发起的子进程内存；拿不到 footprint 时回退 RSS。
- 展示当前 RAM Used、Swap Used、Compressed Memory。
- SwiftUI 设置面板：RAM Max、Swap Max、非前台时间、语言。
- 白名单：5 个默认系统保护项 + 用户自定义 Bundle ID。
- 清理判断：可清理 / 不可清理。
- 自动结束可清理 App：非前台时间超过阈值后直接强制结束清理候选 App。
- 手动结束可清理 App：菜单里 `Clean Apps Now`。
- 日志：菜单里展示最近事件。

当前策略：

- 不再区分 warning / critical。
- 不按 App 类型、Bundle ID 关键词、名称关键词判断是否可清理。
- 不用 App 内存大小判断是否可清理。
- App 不是当前前台 App。
- App 不在白名单。白名单包含默认系统保护项和用户自定义 Bundle ID。
- App 非前台时间达到设置阈值，默认 30 分钟。
- 符合条件后直接强制结束候选 App。
- 每轮最多处理 3 个 App。
- 自动清理每 60 秒最多触发一次。
- 同一个 Bundle ID 10 分钟内不会重复请求退出。
- 前台 App、白名单 App、未达到非前台时间阈值的 App 永不自动退出。

默认系统保护项：

- `com.apple.finder`
- `com.apple.dock`
- `com.apple.WindowServer`
- `com.apple.systempreferences`
- `com.apple.SystemSettings`

多进程说明：

- 菜单展示 App 主进程 + 所有后代进程的 memory footprint。
- 这会覆盖浏览器渲染进程、Electron 子进程等场景。
- 菜单里会显示总内存，并在有子进程时显示子进程数量。

默认阈值：

- RAM Max：100%。
- Use Swap Limit：开启。
- Swap Max：物理内存的一半，最低 2 GB。
- 非前台时间：30 分钟。

说明：Swap 是内存压力发生后的结果，而且有滞后性；`Swap > 0` 不一定表示当前还处在压力中。当前策略里 RAM / Swap 只用于状态显示和阈值展示，不决定某个 App 是否可清理。清理资格只由非前台时间和白名单决定。

## 第二部分：CPU 后台调度

目标：前台 App 保持完整性能，后台 App 按规则降低资源消耗。

暂不进入第一版实现。原因很简单：CPU 控制比直接退出更容易造成卡死、下载中断、后台任务异常。应该先证明白名单和前后台追踪可靠。

第二版再实现：

- 后台降低优先级。
- 后台 CPU 限速。
- 后台完全暂停。
- 切回前台自动恢复。
- 单 App CPU 规则。

## MVP 判断

第一版不是“清理内存神器”，而是一个非前台时长阈值的后台 App 强制结束器。核心能力只有一个：后台 App 超过设置时间且不在白名单时，强制结束它。
