import Foundation

public struct EventLogEntry: Equatable {
    public let date: Date
    public let message: String

    public var menuTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "\(formatter.string(from: date))  \(message)"
    }
}

public protocol EventLogging: AnyObject {
    func append(_ message: String)
}

public final class EventLog: EventLogging {
    private var entries: [EventLogEntry] = []
    private let limit: Int

    public init(limit: Int = 100) {
        self.limit = limit
    }

    public func append(_ message: String) {
        entries.append(EventLogEntry(date: Date(), message: message))
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
    }

    public func recentEntries(limit: Int) -> [EventLogEntry] {
        Array(entries.suffix(limit).reversed())
    }
}
