import Dispatch
import Foundation

public final class MemoryPressureWatcher {
    public var onPressure: ((MemoryPressureLevel) -> Void)?

    private let queue: DispatchQueue
    private var source: DispatchSourceMemoryPressure?

    public init(queue: DispatchQueue = DispatchQueue(label: "milu.greenram.memory-pressure")) {
        self.queue = queue
    }

    public func start() {
        guard source == nil else { return }

        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: queue
        )
        self.source = source

        source.setEventHandler { [weak self] in
            guard let self, let source = self.source else { return }
            let data = source.data
            if data.contains(.critical) {
                self.onPressure?(.critical)
            } else if data.contains(.warning) {
                self.onPressure?(.warning)
            }
        }
        source.resume()
    }

    public func stop() {
        source?.cancel()
        source = nil
    }
}
