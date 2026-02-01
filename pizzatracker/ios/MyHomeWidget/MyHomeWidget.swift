import WidgetKit
import SwiftUI

private let appGroupId = "group.tunahanoguz.pizzatracker"
private let dataKey = "text_from_flutter_app"

struct SimpleEntry: TimelineEntry {
    let date: Date
    let text: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), text: "Nothing Ever Happens: --%")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), text: readText()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), text: readText())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readText() -> String {
        let defaults = UserDefaults(suiteName: appGroupId)
        return defaults?.string(forKey: dataKey) ?? "Nothing Ever Happens: --%"
    }
}

struct MyHomeWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.10),
                    Color(red: 0.05, green: 0.08, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.green)
                    Text("NEH SIGNAL")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(.white.opacity(0.90))
                }

                Text(entry.text)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "pizza.fill")
                        .font(.caption2)
                        .foregroundColor(.orange.opacity(0.9))
                    Text("Washington Pizza Tracker")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.65))
                }
            }
            .padding(14)
        }
    }
}

struct MyHomeWidget: Widget {
    let kind: String = "MyHomeWidgetExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MyHomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NEH Signal")
        .description("Shows Nothing Ever Happens %")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
