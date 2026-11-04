import AppKit
import MacAotoKillCore
import SwiftUI

/// RAM / Swap 指标的展示数据。填充色表达严重程度：正常 → 接近上限 → 超限。
struct MemoryMetric {
    let title: String
    let systemImage: String
    let value: String
    let total: String
    let detail: String
    let progress: Double
    let color: Color
}

enum MemoryMetrics {
    static func ram(_ state: DashboardState) -> MemoryMetric {
        let memory = state.memory
        let localizer = state.localizer
        let isExceeded = memory.usedPhysicalPercent >= state.ramLimitPercent
        return MemoryMetric(
            title: localizer.t("menu.ram"),
            systemImage: "memorychip",
            value: ByteFormatter.memory(memory.usedPhysicalBytes),
            total: ByteFormatter.memory(memory.totalPhysicalBytes),
            detail: localizer.t("overview.ramUsedPercent", PercentFormatter.compact(memory.usedPhysicalPercent)),
            progress: memory.usedPhysicalPercent / 100,
            color: isExceeded ? Palette.critical : Palette.brand
        )
    }

    static func swap(_ state: DashboardState) -> MemoryMetric {
        let memory = state.memory
        let localizer = state.localizer
        let denominator = state.swapLimitEnabled ? state.swapLimitBytes : memory.swapTotalBytes
        let progress = denominator > 0 ? min(Double(memory.swapUsedBytes) / Double(denominator), 1) : 0
        let color: Color
        if state.swapLimitEnabled && memory.swapUsedBytes >= state.swapLimitBytes {
            color = Palette.critical
        } else if state.swapLimitEnabled && progress >= 0.75 {
            color = Palette.warning
        } else {
            color = Palette.brand
        }
        return MemoryMetric(
            title: localizer.t("menu.swap"),
            systemImage: "arrow.triangle.2.circlepath",
            value: ByteFormatter.memory(memory.swapUsedBytes),
            total: state.swapLimitEnabled
                ? ByteFormatter.memory(state.swapLimitBytes)
                : ByteFormatter.memory(memory.swapTotalBytes),
            detail: state.swapLimitEnabled
                ? "\(localizer.t("settings.swapLimit")) \(ByteFormatter.memory(state.swapLimitBytes))"
                : localizer.t("overview.swapLimitOff"),
            progress: progress,
            color: color
        )
    }
}

// MARK: - 内存构成

struct MemorySegment: Identifiable {
    let id: String
    let title: String
    let bytes: UInt64
    let color: Color
}

enum MemoryComposition {
    /// 固定顺序：App 内存、系统进程、联动内存、已压缩、缓存文件，最后是剩余可用。
    ///
    /// 系统的 App 内存（匿名页 − 可清除页）包含所有进程，不只是 App。进程 footprint 还含压缩、swap 和图形内存，
    /// 总和远超物理内存，不能直接画进条里；所以总量仍用系统口径，按 App 进程树与系统进程的 footprint 占比拆成两段。
    /// 系统进程还没采样完时（`systemProcessBytes` 为 nil）不拆。
    static func segments(
        _ memory: SystemMemorySnapshot,
        appProcessBytes: UInt64,
        systemProcessBytes: UInt64?,
        localizer: Localizer
    ) -> [MemorySegment] {
        var appBytes = memory.appMemoryBytes
        var systemBytes: UInt64 = 0
        if let systemProcessBytes, appProcessBytes + systemProcessBytes > 0 {
            let appShare = Double(appProcessBytes) / Double(appProcessBytes + systemProcessBytes)
            appBytes = UInt64(Double(memory.appMemoryBytes) * appShare)
            systemBytes = memory.appMemoryBytes - appBytes
        }
        let used = [
            MemorySegment(id: "app", title: localizer.t("composition.app"), bytes: appBytes, color: Palette.appMemory),
            MemorySegment(id: "system", title: localizer.t("composition.system"), bytes: systemBytes, color: Palette.systemMemory),
            MemorySegment(id: "wired", title: localizer.t("composition.wired"), bytes: memory.wiredBytes, color: Palette.wired),
            MemorySegment(id: "compressed", title: localizer.t("composition.compressed"), bytes: memory.compressedBytes, color: Palette.compressed),
            MemorySegment(id: "cached", title: localizer.t("composition.cached"), bytes: memory.cachedFilesBytes, color: Palette.cachedFiles)
        ]
        let usedBytes = used.reduce(UInt64(0)) { $0 + $1.bytes }
        let freeBytes = memory.totalPhysicalBytes > usedBytes ? memory.totalPhysicalBytes - usedBytes : 0
        return used + [
            MemorySegment(id: "free", title: localizer.t("composition.free"), bytes: freeBytes, color: Palette.neutralFill)
        ]
    }
}

/// 堆叠条：段之间留 2pt 间隙，不描边。
struct MemoryCompositionBar: View {
    let segments: [MemorySegment]
    var height: CGFloat = 14

    var body: some View {
        let visible = segments.filter { $0.bytes > 0 }
        let total = Double(visible.reduce(UInt64(0)) { $0 + $1.bytes })
        GeometryReader { geometry in
            let gaps = CGFloat(max(visible.count - 1, 0)) * 2
            let available = max(geometry.size.width - gaps, 0)
            HStack(spacing: 2) {
                ForEach(visible) { segment in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(segment.color)
                        .frame(width: total > 0 ? available * CGFloat(Double(segment.bytes) / total) : 0)
                        .help("\(segment.title) · \(ByteFormatter.memory(segment.bytes))")
                }
            }
        }
        .frame(height: height)
    }
}

struct MemoryCompositionLegend: View {
    let segments: [MemorySegment]
    let totalBytes: UInt64

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(segments) { segment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(segment.color)
                            .frame(width: 10, height: 10)
                        Text(segment.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(ByteFormatter.memory(segment.bytes))
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Text(share(segment.bytes))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func share(_ bytes: UInt64) -> String {
        guard totalBytes > 0 else { return "0%" }
        return PercentFormatter.compact(Double(bytes) / Double(totalBytes) * 100)
    }
}
