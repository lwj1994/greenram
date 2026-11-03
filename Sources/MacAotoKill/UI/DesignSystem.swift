import AppKit
import MacAotoKillCore
import SwiftUI

/// 界面配色。分类色和状态色取自 dataviz 参考色板，内存构成的 4 个分类色已用 validate_palette 校验（明 / 暗两套）。
enum Palette {
    static let brand = Color(nsColor: .systemGreen)

    // 状态色：固定，不随主题变化；展示时总是配图标和文字。
    static let good = Color(hex: 0x0CA30C)
    static let warning = Color(hex: 0xFAB219)
    static let serious = Color(hex: 0xEC835A)
    static let critical = Color(hex: 0xD03B3B)

    // 规则身份色。
    static let autoQuit = Color(light: 0x6250D6, dark: 0x9085E9)
    static let idleTime = Color(light: 0xEB6834, dark: 0xD95926)
    static let memoryLimit = Color(light: 0x2A78D6, dark: 0x3987E5)
    static let whitelist = good

    // 内存构成：分类色 1–4，固定顺序。
    static let appMemory = Color(light: 0x2A78D6, dark: 0x3987E5)
    static let wired = Color(light: 0xEB6834, dark: 0xD95926)
    static let compressed = Color(light: 0x1BAF7A, dark: 0x199E70)
    static let cachedFiles = Color(light: 0xEDA100, dark: 0xC98500)

    static let cardFill = Color(
        nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor.white.withAlphaComponent(0.055) : NSColor.white
        }
    )
    static let hairline = Color.primary.opacity(0.08)
    static let neutralFill = Color.primary.opacity(0.07)
}

extension Color {
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }

    init(light: UInt32, dark: UInt32) {
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                NSColor(hex: appearance.isDark ? dark : light)
            }
        )
    }
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

// MARK: - 状态

extension AppCleanupStatus {
    var color: Color {
        switch self {
        case .cleanable: return Palette.serious
        case .protected: return Palette.good
        case .foreground: return Palette.appMemory
        case .waiting: return Color.secondary
        }
    }

    var systemImage: String {
        switch self {
        case .cleanable: return "sparkles"
        case .protected: return "checkmark.shield.fill"
        case .foreground: return "macwindow"
        case .waiting: return "hourglass"
        }
    }

    func title(_ localizer: Localizer) -> String {
        switch self {
        case .cleanable: return localizer.t("menu.cleanable")
        case .protected: return localizer.t("menu.protected")
        case .foreground: return localizer.t("status.foreground")
        case .waiting: return localizer.t("status.monitoring")
        }
    }
}

struct StatusBadge: View {
    let title: String
    let systemImage: String
    let color: Color

    init(title: String, systemImage: String, color: Color) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
    }

    init(_ status: AppCleanupStatus, localizer: Localizer) {
        self.init(title: status.title(localizer), systemImage: status.systemImage, color: status.color)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.14), in: Capsule())
        .fixedSize()
    }
}

/// 内存整体状态：正常 / 超限。
struct MemoryStatusPill: View {
    let isExceeded: Bool
    let localizer: Localizer

    var body: some View {
        StatusBadge(
            title: isExceeded ? localizer.t("status.exceeded") : localizer.t("status.withinLimits"),
            systemImage: isExceeded ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
            color: isExceeded ? Palette.critical : Palette.good
        )
    }
}

// MARK: - 容器

struct CardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Palette.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            }
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct PageHeader<Accessory: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory()
        }
    }
}

extension PageHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct CardTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// 图标放在带色调的圆角方块里，用于规则、引导页等说明行。
struct TintedIcon: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}

// MARK: - 数据标记

/// 细线进度条：填充色表达状态，底轨是同色的浅阶。
struct MeterBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.16))
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
    }
}

// MARK: - App 图标

@MainActor
enum AppIconCache {
    private static var icons: [String: NSImage] = [:]

    static func icon(bundleID: String, pid: pid_t? = nil) -> NSImage {
        if let icon = icons[bundleID] {
            return icon
        }
        let icon = pid.flatMap { NSRunningApplication(processIdentifier: $0)?.icon }
            ?? NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.icon
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).map {
                NSWorkspace.shared.icon(forFile: $0.path)
            }
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
        icons[bundleID] = icon
        return icon
    }
}

struct AppIconView: View {
    let bundleID: String
    var pid: pid_t?
    var size: CGFloat = 28

    var body: some View {
        Image(nsImage: AppIconCache.icon(bundleID: bundleID, pid: pid))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

// MARK: - 品牌叶子

/// 叶子图形，22×22 坐标系（y 轴向上）。菜单栏图标和界面里的品牌标记共用这一份路径，偶奇填充挖出叶脉。
enum LeafGlyph {
    static let canvasSize: CGFloat = 22

    static let path: CGPath = {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 5.1, y: 3.4))
        path.addCurve(to: CGPoint(x: 5.7, y: 7.1), control1: CGPoint(x: 4.3, y: 4.4), control2: CGPoint(x: 4.8, y: 5.7))
        path.addCurve(to: CGPoint(x: 10.4, y: 14.6), control1: CGPoint(x: 6.7, y: 10.0), control2: CGPoint(x: 8.1, y: 12.7))
        path.addCurve(to: CGPoint(x: 18.1, y: 18.7), control1: CGPoint(x: 13.0, y: 16.7), control2: CGPoint(x: 15.6, y: 17.2))
        path.addCurve(to: CGPoint(x: 19.4, y: 18.1), control1: CGPoint(x: 18.9, y: 19.2), control2: CGPoint(x: 19.5, y: 18.9))
        path.addCurve(to: CGPoint(x: 18.7, y: 10.0), control1: CGPoint(x: 19.7, y: 15.4), control2: CGPoint(x: 19.5, y: 12.6))
        path.addCurve(to: CGPoint(x: 12.5, y: 3.7), control1: CGPoint(x: 17.6, y: 6.6), control2: CGPoint(x: 15.4, y: 4.5))
        path.addCurve(to: CGPoint(x: 7.8, y: 3.3), control1: CGPoint(x: 10.7, y: 3.2), control2: CGPoint(x: 9.2, y: 3.4))
        path.addCurve(to: CGPoint(x: 6.3, y: 1.8), control1: CGPoint(x: 7.0, y: 3.0), control2: CGPoint(x: 6.8, y: 2.3))
        path.addCurve(to: CGPoint(x: 4.2, y: 2.0), control1: CGPoint(x: 5.6, y: 1.2), control2: CGPoint(x: 4.5, y: 1.3))
        path.addCurve(to: CGPoint(x: 5.1, y: 3.4), control1: CGPoint(x: 3.9, y: 2.6), control2: CGPoint(x: 4.4, y: 3.1))
        path.closeSubpath()

        path.move(to: CGPoint(x: 6.9, y: 4.0))
        path.addCurve(to: CGPoint(x: 15.9, y: 14.5), control1: CGPoint(x: 8.0, y: 7.9), control2: CGPoint(x: 11.5, y: 12.5))
        path.addCurve(to: CGPoint(x: 15.1, y: 14.9), control1: CGPoint(x: 16.3, y: 14.8), control2: CGPoint(x: 16.0, y: 15.1))
        path.addCurve(to: CGPoint(x: 7.6, y: 5.9), control1: CGPoint(x: 11.8, y: 13.1), control2: CGPoint(x: 8.9, y: 9.2))
        path.addCurve(to: CGPoint(x: 6.9, y: 4.0), control1: CGPoint(x: 7.2, y: 5.1), control2: CGPoint(x: 6.9, y: 4.4))
        path.closeSubpath()
        return path
    }()

    static func statusImage(isExceeded: Bool) -> NSImage {
        let size = NSSize(width: canvasSize, height: canvasSize)
        return NSImage(size: size, flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(path)
            context.setFillColor((isExceeded ? NSColor.systemRed : NSColor.systemGreen).cgColor)
            context.fillPath(using: .evenOdd)
            return true
        }
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / LeafGlyph.canvasSize
        let transform = CGAffineTransform(
            translationX: rect.midX - LeafGlyph.canvasSize * scale / 2,
            y: rect.midY + LeafGlyph.canvasSize * scale / 2
        )
        .scaledBy(x: scale, y: -scale)
        return Path(LeafGlyph.path).applying(transform)
    }
}

struct LeafMark: View {
    var color: Color = Palette.brand
    var size: CGFloat = 18

    var body: some View {
        LeafShape()
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: size, height: size)
    }
}
