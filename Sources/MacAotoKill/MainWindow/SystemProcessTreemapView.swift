import Darwin
import MacAotoKillCore
import SwiftUI

/// 平铺展示系统进程的内存：块面积 = 内存，红色 = 疑似泄漏，蓝色 = 当前用户的进程，灰色 = root 和其他用户。
/// 占比过小的进程合并为「其他」。右键可强制退出。
struct SystemProcessTreemapView: View {
    let processes: [SystemProcessUsage]
    let suspectedLeakPIDs: Set<pid_t>
    let localizer: Localizer
    let viewModel: DashboardViewModel
    let onSelect: (SystemProcessUsage?) -> Void

    @State private var hoveredTileID: String?

    private static let minimumShare = 0.006

    fileprivate struct Tile: Identifiable {
        let id: String
        let process: SystemProcessUsage?
        let otherProcessCount: Int
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

    /// processes 已按内存降序。
    private func makeTiles() -> [Tile] {
        let total = processes.reduce(UInt64(0)) { $0 + $1.memoryBytes }
        guard total > 0 else { return [] }

        var tiles: [Tile] = []
        var others: [SystemProcessUsage] = []
        for process in processes {
            if Double(process.memoryBytes) / Double(total) >= Self.minimumShare {
                tiles.append(Tile(id: "\(process.pid)", process: process, otherProcessCount: 0, memoryBytes: process.memoryBytes))
            } else {
                others.append(process)
            }
        }

        if others.count == 1, let process = others.first {
            tiles.append(Tile(id: "\(process.pid)", process: process, otherProcessCount: 0, memoryBytes: process.memoryBytes))
        } else if !others.isEmpty {
            tiles.append(
                Tile(
                    id: "other",
                    process: nil,
                    otherProcessCount: others.count,
                    memoryBytes: others.reduce(0) { $0 + $1.memoryBytes }
                )
            )
        }
        return tiles
    }

    @ViewBuilder
    private func tileView(_ tile: Tile, size: CGSize) -> some View {
        let base = SystemProcessTileView(
            tile: tile,
            size: size,
            isHovered: hoveredTileID == tile.id,
            isSuspectedLeak: tile.process.map { suspectedLeakPIDs.contains($0.pid) } ?? false,
            localizer: localizer
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredTileID = hovering ? tile.id : (hoveredTileID == tile.id ? nil : hoveredTileID)
        }
        .onTapGesture {
            onSelect(tile.process)
        }
        .help(helpText(tile))

        if let process = tile.process {
            base.contextMenu {
                SystemProcessMenuItems(process: process, localizer: localizer, viewModel: viewModel)
            }
        } else {
            base
        }
    }

    private func helpText(_ tile: Tile) -> String {
        guard let process = tile.process else {
            return "\(localizer.t("treemap.otherProcesses", tile.otherProcessCount)) · \(ByteFormatter.memory(tile.memoryBytes))"
        }
        return [process.entry.executablePath ?? process.name, "PID \(process.pid)", ByteFormatter.memory(process.memoryBytes)]
            .joined(separator: " · ")
    }
}

private struct SystemProcessTileView: View {
    let tile: SystemProcessTreemapView.Tile
    let size: CGSize
    let isHovered: Bool
    let isSuspectedLeak: Bool
    let localizer: Localizer

    private var isLarge: Bool {
        size.width >= 150 && size.height >= 104
    }

    private var fill: Color {
        guard let process = tile.process else {
            return Palette.neutralFill.opacity(isHovered ? 1.6 : 1)
        }
        if isSuspectedLeak {
            return Palette.critical.opacity(isHovered ? 0.32 : 0.22)
        }
        if process.entry.userID == getuid() {
            return Palette.appMemory.opacity(isHovered ? 0.26 : 0.16)
        }
        return Color.primary.opacity(isHovered ? 0.12 : 0.07)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(fill)

            if size.width >= 64 && size.height >= 42 {
                labels
                    .padding(isLarge ? 10 : 7)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: isLarge ? 4 : 2) {
            HStack(spacing: 5) {
                if size.width >= 96 {
                    Image(systemName: tile.process == nil ? "square.grid.2x2" : (tile.process?.isRoot == true ? "lock.fill" : "gearshape.fill"))
                        .font(.system(size: isLarge ? 12 : 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(tile.process?.name ?? localizer.t("treemap.otherProcesses", tile.otherProcessCount))
                    .font(.system(size: isLarge ? 13 : 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text(ByteFormatter.memory(tile.memoryBytes))
                .font(.system(size: isLarge ? 12 : 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)

            if isSuspectedLeak, size.height >= 76, size.width >= 110 {
                Spacer(minLength: 0)
                StatusBadge(
                    title: localizer.t("systemProcesses.suspectedLeak"),
                    systemImage: "exclamationmark.triangle.fill",
                    color: Palette.critical
                )
            }
        }
    }
}

struct SystemProcessTreemapLegend: View {
    let localizer: Localizer

    var body: some View {
        HStack(spacing: 14) {
            item(localizer.t("systemProcesses.suspectedLeak"), color: Palette.critical)
            item(localizer.t("systemProcesses.currentUser"), color: Palette.appMemory)
            item(localizer.t("systemProcesses.otherUsers"), color: Color.primary.opacity(0.18))
        }
    }

    private func item(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
