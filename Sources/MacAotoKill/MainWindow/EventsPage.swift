import AppleViewModel
import MacAotoKillCore
import SwiftUI

@MainActor
struct EventsPage: View {
    @WatchViewModel private var viewModel: DashboardViewModel

    init(viewModelSpec: ViewModelSpec<DashboardViewModel>) {
        self._viewModel = WatchViewModel(viewModelSpec)
    }

    private var localizer: Localizer {
        viewModel.state.localizer
    }

    private var days: [(day: Date, entries: [EventLogEntry])] {
        let calendar = Calendar.current
        var result: [(day: Date, entries: [EventLogEntry])] = []
        for entry in viewModel.state.events {
            let day = calendar.startOfDay(for: entry.date)
            if let last = result.indices.last, result[last].day == day {
                result[last].entries.append(entry)
            } else {
                result.append((day, [entry]))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    title: localizer.t("menu.recentEvents"),
                    subtitle: localizer.t("settings.logRetentionHint")
                ) {
                    Button {
                        viewModel.exportLogs()
                    } label: {
                        Label(localizer.t("settings.exportLogs"), systemImage: "square.and.arrow.up")
                    }
                }

                if viewModel.state.events.isEmpty {
                    Text(localizer.t("menu.noEvents"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else {
                    ForEach(days, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dayTitle(group.day))
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(group.entries.enumerated()), id: \.offset) { index, entry in
                                    if index > 0 {
                                        Divider()
                                    }
                                    EventRow(entry: entry)
                                }
                            }
                            .card(padding: 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private func dayTitle(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localizer.language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: day)
    }
}

private struct EventRow: View {
    let entry: EventLogEntry

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(Self.timeFormatter.string(from: entry.date))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)
            Text(entry.message)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
