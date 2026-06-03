# MVP 功能梳理

## 第一部分：内存压力释放

目标：当 macOS 内存压力升高时，自动退出不在前台、低风险、不在白名单里的后台 App。

已实现：

- 菜单栏常驻。
- 监听前台 App 切换。
- 枚举 Regular GUI App。
- 采样 App memory footprint，并聚合它发起的子进程内存；拿不到 footprint 时回退 RSS。
- 展示当前 RAM Used、Swap Used、Compressed Memory。
- SwiftUI 设置面板：RAM Max、Swap Max、语言。
- 白名单：5 个默认系统保护项 + 用户自定义 Bundle ID。
- 风险分层：低风险 / 中风险 / 高风险。
- 自动结束后台 App：阈值命中后直接强制结束安全候选 App。
- 手动结束后台 App：菜单里 `Quit Background Apps Now`。
- 日志：菜单里展示最近事件。

当前策略：

- 不再区分 warning / critical。
- `RAM Used >= RAM Max` 时触发。
- 开启 `Use Swap Limit` 后，`Swap Used >= Swap Max` 也会触发。
- 触发后直接强制结束安全候选 App。
- 每轮最多处理 3 个 App。
- 250 MB 以下的 App 不处理。
- 前台、白名单、高风险 App 永不自动退出。

默认系统保护项：

- `com.apple.finder`
- `com.apple.dock`
- `com.apple.WindowServer`
- `com.apple.systempreferences`
- `com.apple.SystemSettings`

多进程说明：

- 候选排序使用 App 主进程 + 所有后代进程的 memory footprint。
- 这会覆盖 Xcode 调试进程、浏览器渲染进程、Electron 子进程等场景。
- 菜单里会显示总内存，并在有子进程时显示子进程数量。

默认阈值：

- RAM Max：100%。
- Use Swap Limit：开启。
- Swap Max：物理内存的一半，最低 2 GB。
- 可结束 App 最小内存：250 MB。

说明：Swap 是内存压力发生后的结果，而且有滞后性；`Swap > 0` 不一定表示当前还处在压力中。MVP 里 `RAM Max` 是主触发，`Swap Max` 是兜底触发。关闭 `Use Swap Limit` 表示忽略 Swap 触发，但界面仍会显示当前系统 Swap 使用量。

## 第二部分：CPU 后台调度

目标：前台 App 保持完整性能，后台 App 按规则降低资源消耗。

暂不进入第一版实现。原因很简单：CPU 控制比内存退出更容易造成卡死、下载中断、后台任务异常。应该先证明白名单、风险识别、前后台追踪可靠。

第二版再实现：

- 后台降低优先级。
- 后台 CPU 限速。
- 后台完全暂停。
- 切回前台自动恢复。
- 单 App CPU 规则。

## MVP 判断

第一版不是“清理内存神器”，而是一个硬阈值后台 App 强制结束器。核心能力只有一个：超过 RAM / Swap 上限时，强制结束安全候选后台 App。
