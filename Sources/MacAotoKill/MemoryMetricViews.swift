import AppKit
import MacAotoKillCore
import SwiftUI

struct MemoryMetricDisplay {
    let title: String
    let systemImage: String
    let value: String
    let detail: String
    let progress: Double
    let isExceeded: Bool
}

enum MemoryMetricDisplays {
    static func ram(
        snapshot: SystemMemorySnapshot,
        ramLimitPercent: Double,
        localizer: Localizer
    ) -> MemoryMetricDisplay {
        MemoryMetricDisplay(
            title: localizer.t("settings.ramUsed"),
            systemImage: "memorychip",
            value: "\(ByteFormatter.memory(snapshot.usedPhysicalBytes)) / \(ByteFormatter.memory(snapshot.totalPhysicalBytes))",
            detail: PercentFormatter.compact(snapshot.usedPhysicalPercent),
            progress: snapshot.usedPhysicalPercent / 100,
            isExceeded: snapshot.usedPhysicalPercent >= ramLimitPercent
        )
    }

    static func swap(
        snapshot: SystemMemorySnapshot,
        swapLimitEnabled: Bool,
        swapLimitBytes: UInt64,
        localizer: Localizer
    ) -> MemoryMetricDisplay {
        let denominator = swapLimitEnabled ? swapLimitBytes : snapshot.swapTotalBytes

        return MemoryMetricDisplay(
            title: localizer.t("settings.swapUsed"),
            systemImage: "arrow.triangle.2.circlepath",
            value: "\(ByteFormatter.memory(snapshot.swapUsedBytes)) / \(ByteFormatter.memory(snapshot.swapTotalBytes))",
            detail: swapLimitEnabled
                ? "\(localizer.t("settings.swapLimit")) \(ByteFormatter.memory(swapLimitBytes))"
                : localizer.t("settings.swapMinimumHint"),
            progress: progress(Double(snapshot.swapUsedBytes), total: Double(denominator)),
            isExceeded: swapLimitEnabled && snapshot.swapUsedBytes >= swapLimitBytes
        )
    }

    private static func progress(_ value: Double, total: Double) -> Double {
        guard total > 0 else { return 0 }
        return min(max(value / total, 0), 1)
    }
}

struct MemoryMetricSummaryView: View {
    let metric: MemoryMetricDisplay
    var ringSize: CGFloat = 58
    var iconSize: CGFloat = 18
    var minHeight: CGFloat = 82

    private var color: Color {
        MemoryMetricColor.status(metric.isExceeded)
    }

    var body: some View {
        HStack(spacing: 13) {
            MemoryGaugeRing(progress: metric.progress, color: color)
                .frame(width: ringSize, height: ringSize)
                .overlay {
                    Image(systemName: metric.systemImage)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(color)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(metric.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                Text(metric.value)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(metric.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: minHeight)
    }
}

struct MemoryDashboardMenuContent: View {
    static let width: CGFloat = 392

    let title: String
    let statusText: String
    let isExceeded: Bool
    let icon: NSImage
    let ramMetric: MemoryMetricDisplay
    let swapMetric: MemoryMetricDisplay

    private var statusColor: Color {
        MemoryMetricColor.status(isExceeded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            metricCard
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(width: Self.width, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            if isExceeded {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(statusColor.opacity(0.22), lineWidth: 1)
                    }
            }
        }
        .frame(width: Self.width - 32, height: 24, alignment: .center)
    }

    private var metricCard: some View {
        VStack(spacing: 0) {
            MemoryMetricSummaryView(metric: ramMetric, ringSize: 46, iconSize: 15, minHeight: 60)
            Divider()
                .padding(.leading, 65)
            MemoryMetricSummaryView(metric: swapMetric, ringSize: 46, iconSize: 15, minHeight: 60)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .frame(width: Self.width - 32, alignment: .leading)
    }
}

enum MemoryMetricColor {
    static func status(_ isExceeded: Bool) -> Color {
        Color(nsColor: isExceeded ? .systemRed : .systemGreen)
    }
}

private struct MemoryGaugeRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}
