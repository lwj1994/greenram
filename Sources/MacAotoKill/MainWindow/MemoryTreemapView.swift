import MacAotoKillCore
import SwiftUI

/// 平铺展示所有 App 的内存：块面积 = 进程树合计内存，块颜色 = 清理状态。占比过小的 App 合并为「其他」。
struct MemoryTreemapView: View {
    let apps: [DashboardApp]
    let localizer: Localizer
    let onSelect: (DashboardApp?) -> Void
    var contextMenu: (DashboardApp) -> AnyView = { _ in AnyView(EmptyView()) }

    @State private var hoveredTileID: String?

    private static let minimumShare = 0.006

    fileprivate struct Tile: Identifiable {
        let id: String
        let app: DashboardApp?
        let otherAppCount: Int
        let memoryBytes: UInt64
    }

    var body: some View {
        GeometryReader { geometry in
            let tiles = makeTiles()
            let rects = TreemapLayout.squarified(
                tiles.map { Double($0.memoryBytes) },
                in: CGRect(origin: .zero, size: geometry.size)
            )
            ZStack(alignment: .topLeading) {
                ForEach(Array(tiles.enumerated()), id: \.element.id) { index, tile in
                    let rect = rects[index].insetBy(dx: 1, dy: 1)
                    if rect.width > 2, rect.height > 2 {
                        tileView(tile, size: rect.size)
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                    }
                }
            }
        }
    }

    private func makeTiles() -> [Tile] {
        let total = apps.reduce(UInt64(0)) { $0 + $1.memoryBytes }
        guard total > 0 else { return [] }

        var tiles: [Tile] = []
        var others: [DashboardApp] = []
        for app in apps.sorted(by: { $0.memoryBytes > $1.memoryBytes }) {
            if Double(app.memoryBytes) / Double(total) >= Self.minimumShare {
                tiles.append(Tile(id: "\(app.pid)", app: app, otherAppCount: 0, memoryBytes: app.memoryBytes))
            } else {
                others.append(app)
            }
        }

        if others.count == 1, let app = others.first {
            tiles.append(Tile(id: "\(app.pid)", app: app, otherAppCount: 0, memoryBytes: app.memoryBytes))
        } else if !others.isEmpty {
            tiles.append(
                Tile(
                    id: "other",
                    app: nil,
                    otherAppCount: others.count,
                    memoryBytes: others.reduce(0) { $0 + $1.memoryBytes }
                )
            )
        }
        return tiles
    }

    @ViewBuilder
    private func tileView(_ tile: Tile, size: CGSize) -> some View {
        let isHovered = hoveredTileID == tile.id
        let base = TreemapTileView(tile: tile, size: size, isHovered: isHovered, localizer: localizer)
            .contentShape(Rectangle())
            .onHover { hovering in
                hoveredTileID = hovering ? tile.id : (hoveredTileID == tile.id ? nil : hoveredTileID)
            }
            .onTapGesture {
                onSelect(tile.app)
            }
            .help(helpText(tile))

        if let app = tile.app {
            base.contextMenu { contextMenu(app) }
        } else {
            base
        }
    }

    private func helpText(_ tile: Tile) -> String {
        guard let app = tile.app else {
            return "\(localizer.t("treemap.otherApps", tile.otherAppCount)) · \(ByteFormatter.memory(tile.memoryBytes))"
        }
        var parts = [app.displayName, ByteFormatter.memory(app.memoryBytes), app.status.title(localizer)]
        if app.childProcessCount > 0 {
            parts.append(localizer.t("menu.childProcessCount", app.childProcessCount))
        }
        return parts.joined(separator: " · ")
    }
}

private struct TreemapTileView: View {
    let tile: MemoryTreemapView.Tile
    let size: CGSize
    let isHovered: Bool
    let localizer: Localizer

    private var isLarge: Bool {
        size.width >= 150 && size.height >= 104
    }

    private var fill: Color {
        guard let app = tile.app else {
            return Palette.neutralFill.opacity(isHovered ? 1.6 : 1)
        }
        switch app.status {
        case .waiting:
            return Color.primary.opacity(isHovered ? 0.12 : 0.07)
        case .foreground:
            return app.status.color.opacity(isHovered ? 0.26 : 0.16)
        case .cleanable, .protected:
            return app.status.color.opacity(isHovered ? 0.32 : 0.22)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fill)

            if size.width >= 64 && size.height >= 42 {
                labels
                    .padding(isLarge ? 10 : 7)
            } else if let app = tile.app, size.width >= 24, size.height >= 24 {
                AppIconView(bundleID: app.bundleID, pid: app.pid, size: min(16, size.width - 8, size.height - 8))
                    .padding(4)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: isLarge ? 4 : 2) {
            HStack(spacing: 6) {
                if let app = tile.app, size.width >= 96 {
                    AppIconView(bundleID: app.bundleID, pid: app.pid, size: isLarge ? 24 : 16)
                } else if tile.app == nil {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(tile.app?.displayName ?? localizer.t("treemap.otherApps", tile.otherAppCount))
                    .font(.system(size: isLarge ? 13 : 11, weight: .semibold))
                    .lineLimit(1)
            }

            Text(ByteFormatter.memory(tile.memoryBytes))
                .font(.system(size: isLarge ? 12 : 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)

            if let app = tile.app, size.height >= 76, size.width >= 110, app.status == .cleanable || app.status == .protected {
                Spacer(minLength: 0)
                StatusBadge(app.status, localizer: localizer)
            }
        }
    }
}

struct TreemapLegend: View {
    let localizer: Localizer

    var body: some View {
        HStack(spacing: 14) {
            ForEach([AppCleanupStatus.cleanable, .protected, .foreground, .waiting], id: \.self) { status in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(status == .waiting ? Color.primary.opacity(0.18) : status.color)
                        .frame(width: 10, height: 10)
                    Text(status.title(localizer))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
