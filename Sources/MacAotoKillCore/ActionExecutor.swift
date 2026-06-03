import AppKit
import Foundation

public protocol AppTerminating: AnyObject {
    func requestQuit(_ app: AppRuntimeState, forceIfNeeded: Bool)
    func forceQuit(_ app: AppRuntimeState)
}

public final class ActionExecutor: AppTerminating {
    private weak var logger: EventLogging?
    private let forceGracePeriod: TimeInterval
    private let localizerProvider: () -> Localizer

    public init(
        logger: EventLogging?,
        forceGracePeriod: TimeInterval = 10,
        localizerProvider: @escaping () -> Localizer = { Localizer() }
    ) {
        self.logger = logger
        self.forceGracePeriod = forceGracePeriod
        self.localizerProvider = localizerProvider
    }

    public func requestQuit(_ app: AppRuntimeState, forceIfNeeded: Bool) {
        let localizer = localizerProvider()
        guard let runningApplication = NSRunningApplication(processIdentifier: app.pid) else {
            logger?.append(localizer.t("event.skippedNoProcess", app.displayName))
            return
        }

        let didRequestQuit = runningApplication.terminate()
        logger?.append(
            didRequestQuit
                ? localizer.t("event.requestedQuit", app.displayName, ByteFormatter.memory(app.memoryBytes))
                : localizer.t("event.quitFailed", app.displayName)
        )

        guard forceIfNeeded else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + forceGracePeriod) { [weak runningApplication, weak logger] in
            guard let runningApplication, !runningApplication.isTerminated else { return }
            let localizer = self.localizerProvider()
            let didForceQuit = runningApplication.forceTerminate()
            logger?.append(
                didForceQuit
                    ? localizer.t("event.forceTerminated", app.displayName)
                    : localizer.t("event.forceTerminateFailed", app.displayName)
            )
        }
    }

    public func forceQuit(_ app: AppRuntimeState) {
        let localizer = localizerProvider()
        guard let runningApplication = NSRunningApplication(processIdentifier: app.pid) else {
            logger?.append(localizer.t("event.skippedNoProcess", app.displayName))
            return
        }

        let didForceQuit = runningApplication.forceTerminate()
        logger?.append(
            didForceQuit
                ? localizer.t("event.forceTerminated", app.displayName)
                : localizer.t("event.forceTerminateFailed", app.displayName)
        )
    }
}
