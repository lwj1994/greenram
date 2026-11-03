import AppleViewModel
import MacAotoKillCore
import SwiftUI

@MainActor
struct AppsPage: View {
    private enum Filter: CaseIterable, Hashable {
        case all
        case cleanable
        case protected
        case autoQuit
    }

    @WatchViewModel private var viewModel: DashboardViewModel
    @State private var filter: Filter = .all
    @State private var searchText = ""
    @State private var expandedPIDs: Set<pid_t> = []
    @State private var highlightedPID: pid_t?

    init(viewModelSpec: ViewModelSpec<DashboardViewModel>) {
        self._viewModel = WatchViewModel(viewModelSpec)
    }

    private var state: DashboardState {
        viewModel.state
    }

    private var localizer: Localizer {
        state.localizer
    }

    private var filteredApps: [DashboardApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return state.apps.filter { app in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .cleanable: matchesFilter = app.status == .cleanable
            case .protected: matchesFilter = app.status == .protected
            case .autoQuit: matchesFilter = app.isAutoQuit
            }
            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }
            return app.displayName.localizedCaseInsensitiveContains(query)
                || app.bundleID.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PageHeader(
                        title: localizer.t("menu.backgroundApps"),
                        subtitle: localizer.t("apps.subtitle", state.apps.count, ByteFormatter.memory(state.totalAppMemoryBytes))
                    ) {
                        CleanNowButton(viewModel: viewModel, localizer: localizer)
                    }

                    HStack(spacing: 12) {
                        Picker("", selection: $filter) {
                            ForEach(Filter.allCases, id: \.self) { filter in
                                Text(title(for: filter)).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()

                        Spacer()

                        SearchField(text: $searchText, prompt: localizer.t("apps.search"))
                            .frame(width: 240)
                    }

                    let apps = filteredApps
                    let maxMemoryBytes = state.apps.map(\.memoryBytes).max() ?? 0
                    if apps.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(apps) { app in
                                AppRow(
                                    app: app,
                                    maxMemoryBytes: maxMemoryBytes,
                                    isExpanded: expandedPIDs.contains(app.pid),
                                    isHighlighted: highlightedPID == app.pid,
                                    localizer: localizer,
                                    viewModel: viewModel,
                                    onToggleExpanded: { toggleExpanded(app.pid) }
                                )
                                .id(app.pid)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .onAppear {
                focusRequestedApp(proxy)
            }
            .onChange(of: state.focusedAppPID) { _ in
                focusRequestedApp(proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(localizer.t("apps.empty"))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func title(for filter: Filter) -> String {
        switch filter {
        case .all: return localizer.t("apps.filterAll")
        case .cleanable: return localizer.t("menu.cleanable")
        case .protected: return localizer.t("menu.protected")
        case .autoQuit: return localizer.t("apps.filterAutoQuit")
        }
    }

    private func toggleExpanded(_ pid: pid_t) {
        withAnimation(.easeOut(duration: 0.15)) {
            if expandedPIDs.contains(pid) {
                expandedPIDs.remove(pid)
            } else {
                expandedPIDs.insert(pid)
            }
        }
    }

    private func focusRequestedApp(_ proxy: ScrollViewProxy) {
        guard let pid = state.focusedAppPID else { return }
        filter = .all
        searchText = ""
        expandedPIDs.insert(pid)
        highlightedPID = pid
        viewModel.clearFocusedApp()
        DispatchQueue.main.async {
            withAnimation {
                proxy.scrollTo(pid, anchor: .center)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation {
                if highlightedPID == pid {
                    highlightedPID = nil
                }
            }
        }
    }
}

private struct AppRow: View {
    let app: DashboardApp
    let maxMemoryBytes: UInt64
    let isExpanded: Bool
    let isHighlighted: Bool
    let localizer: Localizer
    let viewModel: DashboardViewModel
    let onToggleExpanded: () -> Void

    @State private var isHovered = false

    private var hasChildren: Bool {
        !app.children.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .opacity(hasChildren ? 1 : 0)
                    .frame(width: 12)

                AppIconView(bundleID: app.bundleID, pid: app.pid, size: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(app.displayName)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                        StatusBadge(app.status, localizer: localizer)
                        if app.isAutoQuit {
                            StatusBadge(
                                title: localizer.t("apps.filterAutoQuit"),
                                systemImage: "power",
                                color: Palette.autoQuit
                            )
                        }
                    }
                    Text(detailLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    Text(ByteFormatter.memory(app.memoryBytes))
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    MeterBar(
                        progress: maxMemoryBytes > 0 ? Double(app.memoryBytes) / Double(maxMemoryBytes) : 0,
                        color: Palette.appMemory,
                        height: 4
                    )
                    .frame(width: 140)
                }

                Menu {
                    AppRuleMenuItems(app: app, viewModel: viewModel, localizer: localizer)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 15))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(app.isOwnApp)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                if hasChildren {
                    onToggleExpanded()
                }
            }

            if isExpanded && hasChildren {
                Divider()
                    .padding(.leading, 70)
                ChildProcessList(app: app, localizer: localizer)
                    .padding(.leading, 70)
                    .padding(.trailing, 14)
                    .padding(.vertical, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted ? Palette.brand.opacity(0.12) : Palette.cardFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isHighlighted ? Palette.brand.opacity(0.5) : (isHovered ? Color.primary.opacity(0.14) : Palette.hairline),
                    lineWidth: 1
                )
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            AppRuleMenuItems(app: app, viewModel: viewModel, localizer: localizer)
        }
    }

    private var detailLine: String {
        var parts: [String] = []
        if app.isOwnApp {
            parts.append(localizer.t("apps.ownApp"))
        } else if app.status == .foreground {
            parts.append(localizer.t("status.foreground"))
        } else {
            parts.append(
                localizer.t(
                    "apps.backgroundProgress",
                    DurationFormatter.plain(app.backgroundDuration, localizer: localizer),
                    DurationFormatter.plain(app.backgroundThreshold, localizer: localizer)
                )
            )
        }
        if let limit = app.memoryLimitBytes {
            parts.append(localizer.t("apps.memoryLimit", ByteFormatter.memory(limit)))
        }
        if app.childProcessCount > 0 {
            parts.append(localizer.t("menu.childProcessCount", app.childProcessCount))
        }
        return parts.joined(separator: " · ")
    }
}

private struct ChildProcessList: View {
    let app: DashboardApp
    let localizer: Localizer

    private let visibleLimit = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(localizer.t("apps.childProcesses", app.childProcessCount, ByteFormatter.memory(app.childMemoryBytes)))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            ForEach(app.children.prefix(visibleLimit), id: \.label) { summary in
                HStack(spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(summary.processCount > 1 ? "\(summary.label) ×\(summary.processCount)" : summary.label)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if summary.cleanableCount > 0 {
                        StatusBadge(
                            title: localizer.t("menu.childProcessCleanable", summary.cleanableCount),
                            systemImage: "moon.zzz.fill",
                            color: Palette.autoQuit
                        )
                    }
                    Spacer(minLength: 8)
                    Text(ByteFormatter.memory(summary.memoryBytes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            let hidden = app.children.dropFirst(visibleLimit)
            if !hidden.isEmpty {
                Text(
                    localizer.t(
                        "menu.childProcessOthers",
                        hidden.reduce(0) { $0 + $1.processCount },
                        ByteFormatter.memory(hidden.reduce(0) { $0 + $1.memoryBytes })
                    )
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Palette.cardFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        }
    }
}
