import WidgetKit
import SwiftUI

private let appGroupId = "group.com.efe.lifenotes"

// MARK: - Entry

struct PizzaEntry: TimelineEntry {
    let date: Date
    let title: String
    let value: String
    let subtitle: String
    let updatedAt: String
}

// MARK: - Provider

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> PizzaEntry {
        PizzaEntry(
            date: Date(),
            title: "Pizza Tracker",
            value: "—",
            subtitle: "Signal",
            updatedAt: "—"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PizzaEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PizzaEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> PizzaEntry {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return PizzaEntry(
                date: Date(),
                title: "Pizza Tracker",
                value: "—",
                subtitle: "Signal",
                updatedAt: "—"
            )
        }

        let title = defaults.string(forKey: "widget_title") ?? "Pizza Tracker"
        let value = defaults.string(forKey: "widget_value") ?? "—"
        let subtitle = defaults.string(forKey: "widget_subtitle") ?? "Signal"

        let rawUpdated = defaults.string(forKey: "widget_updated_at") ?? "—"
        let updatedAt = formatUpdatedAt(rawUpdated)

        return PizzaEntry(
            date: Date(),
            title: title,
            value: value,
            subtitle: subtitle,
            updatedAt: updatedAt
        )
    }

    private func formatUpdatedAt(_ s: String) -> String {
        if s == "—" { return "—" }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let d = iso.date(from: s) ?? ISO8601DateFormatter().date(from: s) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "MMM d, HH:mm"
            return f.string(from: d)
        }

        if s.count > 24 { return String(s.prefix(24)) + "…" }
        return s
    }
}

// MARK: - View

struct PizzaWidgetView: View {
    let entry: PizzaEntry

    private var bg: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.04, green: 0.05, blue: 0.10),
                Color(red: 0.06, green: 0.08, blue: 0.16),
                Color(red: 0.03, green: 0.04, blue: 0.10),
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            bg

            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title.uppercased())
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)

                Text(entry.value)
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(entry.subtitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)

                Text("Updated: \(entry.updatedAt)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            .padding(14)
        }
        // ✅ iOS 17+ "please adopt containerBackground API" uyarısını çözer
        .applyWidgetBackground(bg)
    }
}

// MARK: - Widget

struct MyHomeWidget: Widget {
    // Flutter: HomeWidget.updateWidget(iOSName: "MyHomeWidget") ile aynı olmalı
    let kind: String = "MyHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PizzaWidgetView(entry: entry)
        }
        .configurationDisplayName("Pizza Tracker")
        .description("Shows the selected signal on your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - iOS 17+ containerBackground helper

private extension View {
    @ViewBuilder
    func applyWidgetBackground(_ bg: LinearGradient) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(bg, for: .widget)
        } else {
            self
        }
    }
}
