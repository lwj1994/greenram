import MacAotoKillCore
import SwiftUI

/// 首次启动的引导：介绍 GreenRAM 做什么、清理规则、以及之后在哪里找到它。
struct OnboardingView: View {
    static let size = CGSize(width: 720, height: 540)

    let localizer: Localizer
    let onFinish: () -> Void

    @State private var pageIndex = 0
    @State private var isMovingForward = true

    private struct Item {
        let systemImage: String
        let color: Color
        let title: String
        let detail: String
    }

    private enum Hero {
        case leaf
        case symbol(String, Color)
    }

    private struct Page {
        let hero: Hero
        let title: String
        let message: String
        let items: [Item]
    }

    private var pages: [Page] {
        [
            Page(
                hero: .leaf,
                title: localizer.t("onboarding.welcomeTitle"),
                message: localizer.t("onboarding.welcomeMessage"),
                items: [
                    Item(systemImage: "square.grid.2x2", color: Palette.appMemory, title: localizer.t("onboarding.insightTitle"), detail: localizer.t("onboarding.insightDetail")),
                    Item(systemImage: "sparkles", color: Palette.serious, title: localizer.t("onboarding.cleanTitle"), detail: localizer.t("onboarding.cleanDetail")),
                    Item(systemImage: "terminal", color: Palette.autoQuit, title: localizer.t("onboarding.childTitle"), detail: localizer.t("onboarding.childDetail"))
                ]
            ),
            Page(
                hero: .symbol("slider.horizontal.3", Palette.memoryLimit),
                title: localizer.t("onboarding.rulesTitle"),
                message: localizer.t("onboarding.rulesMessage", Self.minutes(MemoryPolicyDefaults.minimumBackgroundDuration)),
                items: [
                    Item(systemImage: "checkmark.shield.fill", color: Palette.whitelist, title: localizer.t("menu.whitelist"), detail: localizer.t("onboarding.whitelistDetail")),
                    Item(systemImage: "power", color: Palette.autoQuit, title: localizer.t("settings.autoQuitApps"), detail: localizer.t("onboarding.autoQuitDetail")),
                    Item(systemImage: "macwindow", color: Palette.memoryLimit, title: localizer.t("onboarding.ordinaryTitle"), detail: localizer.t("onboarding.ordinaryDetail")),
                    Item(systemImage: "terminal", color: Palette.idleTime, title: localizer.t("onboarding.childRuleTitle"), detail: localizer.t(
                        "onboarding.childRuleDetail",
                        Self.minutes(Self.childPolicy.idleDuration),
                        ByteFormatter.memory(Self.childPolicy.minimumMemoryBytes)
                    ))
                ]
            ),
            Page(
                hero: .symbol("checkmark", Palette.brand),
                title: localizer.t("onboarding.readyTitle"),
                message: localizer.t("onboarding.readyMessage"),
                items: [
                    Item(systemImage: "leaf.fill", color: Palette.brand, title: localizer.t("onboarding.menuBarTitle"), detail: localizer.t("onboarding.menuBarDetail")),
                    Item(systemImage: "macwindow", color: Palette.appMemory, title: localizer.t("onboarding.mainWindowTitle"), detail: localizer.t("onboarding.mainWindowDetail")),
                    Item(systemImage: "slider.horizontal.3", color: Palette.idleTime, title: localizer.t("onboarding.defaultsTitle"), detail: localizer.t(
                        "onboarding.defaultsDetail",
                        Self.minutes(MemoryPolicyDefaults.minimumBackgroundDuration),
                        ByteFormatter.memory(MemoryPolicyDefaults.defaultSwapLimitBytes),
                        MemoryPolicyDefaults.maxAppsPerSweep
                    ))
                ]
            )
        ]
    }

    private static let childPolicy = IdleChildProcessPolicy()

    private static func minutes(_ interval: TimeInterval) -> Int {
        Int(interval / 60)
    }

    private var isLastPage: Bool {
        pageIndex == pages.count - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                pageView(pages[pageIndex])
                    .id(pageIndex)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: isMovingForward ? .trailing : .leading).combined(with: .opacity),
                            removal: .move(edge: isMovingForward ? .leading : .trailing).combined(with: .opacity)
                        )
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            bottomBar
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            LinearGradient(
                colors: [Palette.brand.opacity(0.10), Color(nsColor: .windowBackgroundColor)],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 20) {
            heroView(page.hero)

            VStack(spacing: 8) {
                Text(page.title)
                    .font(.system(size: 26, weight: .bold))
                Text(page.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 540)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(page.items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 12) {
                        TintedIcon(systemImage: item.systemImage, color: item.color, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.callout.weight(.semibold))
                            Text(item.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .frame(maxWidth: 520, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.top, 44)
        .padding(.horizontal, 48)
    }

    @ViewBuilder
    private func heroView(_ hero: Hero) -> some View {
        switch hero {
        case .leaf:
            ZStack {
                Circle()
                    .fill(Palette.brand.opacity(0.14))
                LeafMark(size: 50)
            }
            .frame(width: 84, height: 84)
        case .symbol(let systemImage, let color):
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 84, height: 84)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == pageIndex ? Palette.brand : Color.primary.opacity(0.15))
                        .frame(width: index == pageIndex ? 18 : 7, height: 7)
                }
            }
            .animation(.easeOut(duration: 0.2), value: pageIndex)

            Spacer()

            if pageIndex > 0 {
                Button(localizer.t("onboarding.back")) {
                    move(by: -1)
                }
                .controlSize(.large)
                .keyboardShortcut(.leftArrow, modifiers: [])
            }

            Button(isLastPage ? localizer.t("onboarding.start") : localizer.t("onboarding.continue")) {
                if isLastPage {
                    onFinish()
                } else {
                    move(by: 1)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.brand)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private func move(by offset: Int) {
        isMovingForward = offset > 0
        withAnimation(.easeInOut(duration: 0.28)) {
            pageIndex = min(max(pageIndex + offset, 0), pages.count - 1)
        }
    }
}
