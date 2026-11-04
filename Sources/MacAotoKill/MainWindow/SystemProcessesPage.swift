import AppleViewModel
import Darwin
import MacAotoKillCore
import SwiftUI

/// 不属于任何 App 的进程，按内存排序。右键可强制退出；root 进程会弹管理员密码框。
@MainActor
struct SystemProcessesPage: View {
    @WatchViewModel private var viewModel: DashboardViewModel
    @State private var searchText = ""

    init(viewModelSpec: ViewModelSpec<DashboardViewModel>) {
        self._viewModel = WatchViewModel(viewModelSpec)
    }

    private var state: DashboardState {
        viewModel.state
    }

    private var localizer: Localizer {
        state.localizer
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(
                    title: localizer.t("systemProcesses.title"),
                    subtitle: state.systemProcesses.map {
                        localizer.t("systemProcesses.subtitle", $0.processes.count, ByteFormatter.memory($0.totalMemoryBytes))
                    }
                ) {
                    SearchField(text: $searchText, prompt: localizer.t("systemProcesses.search"))
                        .frame(width: 240)
                }

                if let summary = state.systemProcesses {
                    let processes = filtered(summary.processes)
                    let maxMemoryBytes = summary.processes.first?.memoryBytes ?? 0
                    LazyVStack(spacing: 6) {
                        ForEach(processes) { process in
                            SystemProcessRow(
                                process: process,
                                isSuspectedLeak: state.suspectedLeakPIDs.contains(process.pid),
                                maxMemoryBytes: maxMemoryBytes,
                                localizer: localizer,
                                viewModel: viewModel
                            )
                        }
                    }
                } else {
                    SystemProcessesLoadingView(localizer: localizer)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private func filtered(_ processes: [SystemProcessUsage]) -> [SystemProcessUsage] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return processes }
        return processes.filter { process in
            process.name.localizedCaseInsensitiveContains(query) || String(process.pid) == query
        }
    }
}

/// 概览页的系统进程卡片：只列内存最高的几个，点击进入系统进程页。
struct SystemProcessesCard: View {
    let viewModel: DashboardViewModel
    let localizer: Localizer
    private let visibleCount = 6

    private var state: DashboardState {
        viewModel.state
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                CardTitle(
                    title: localizer.t("systemProcesses.title"),
                    subtitle: state.systemProcesses.map {
                        localizer.t("systemProcesses.cardHint", $0.processes.count, ByteFormatter.memory($0.totalMemoryBytes))
                    }
                )
                Spacer()
                Button {
                    viewModel.select(.systemProcesses)
                } label: {
                    Label(localizer.t("systemProcesses.showAll"), systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
            }

            if let summary = state.systemProcesses {
                let maxMemoryBytes = summary.processes.first?.memoryBytes ?? 0
                VStack(spacing: 6) {
                    ForEach(summary.processes.prefix(visibleCount)) { process in
                        SystemProcessRow(
                            process: process,
                            isSuspectedLeak: state.suspectedLeakPIDs.contains(process.pid),
                            maxMemoryBytes: maxMemoryBytes,
                            localizer: localizer,
                            viewModel: viewModel
                        )
                        .onTapGesture {
                            viewModel.select(.systemProcesses)
                        }
                    }
                }
            } else {
                SystemProcessesLoadingView(localizer: localizer)
            }
        }
        .card(padding: 18)
    }
}

private struct SystemProcessesLoadingView: View {
    let localizer: Localizer

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(localizer.t("systemProcesses.loading"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct SystemProcessRow: View {
    let process: SystemProcessUsage
    let isSuspectedLeak: Bool
    let maxMemoryBytes: UInt64
    let localizer: Localizer
    let viewModel: DashboardViewModel

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            TintedIcon(
                systemImage: process.isRoot ? "lock.fill" : "gearshape.fill",
                color: isSuspectedLeak ? Palette.critical : .secondary,
                size: 26
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(process.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if isSuspectedLeak {
                        StatusBadge(
                            title: localizer.t("systemProcesses.suspectedLeak"),
                            systemImage: "exclamationmark.triangle.fill",
                            color: Palette.critical
                        )
                    }
                }
                Text(detailLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 5) {
                Text(ByteFormatter.memory(process.memoryBytes))
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSuspectedLeak ? Palette.critical : .primary)
                MeterBar(
                    progress: maxMemoryBytes > 0 ? Double(process.memoryBytes) / Double(maxMemoryBytes) : 0,
                    color: isSuspectedLeak ? Palette.critical : Palette.appMemory,
                    height: 4
                )
                .frame(width: 140)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.cardFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isHovered ? Color.primary.opacity(0.14) : Palette.hairline, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(process.entry.executablePath ?? process.name)
        .contextMenu {
            if process.isProtected {
                Text(localizer.t("systemProcesses.protected"))
            } else {
                Button(
                    localizer.t(process.isRoot ? "systemProcesses.forceQuitAdmin" : "apps.forceQuit", process.name),
                    role: .destructive
                ) {
                    viewModel.forceQuitSystemProcess(process)
                }
            }
        }
    }

    private var detailLine: String {
        let owner = process.isRoot
            ? "root"
            : (process.entry.userID == getuid() ? localizer.t("systemProcesses.currentUser") : Self.userName(process.entry.userID))
        return "PID \(process.pid) · \(owner)"
    }

    private static func userName(_ userID: uid_t) -> String {
        guard let passwd = getpwuid(userID) else { return "uid \(userID)" }
        return String(cString: passwd.pointee.pw_name)
    }
}
