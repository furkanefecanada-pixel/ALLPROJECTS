import WidgetKit
import SwiftUI

private let appGroupId = "group.com.efeapps.hydrodaily"
private let dataKey    = "text_from_flutter_app"

struct SharedModel: Codable {
    let note: String?
}

private func readShared() -> SharedModel? {
    guard let defs = UserDefaults(suiteName: appGroupId),
          let json = defs.string(forKey: dataKey),
          let data = json.data(using: .utf8) else {
        return nil
    }
    return try? JSONDecoder().decode(SharedModel.self, from: data)
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let model: SharedModel
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), model: SharedModel(note: "Write a note ✨"))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let model = readShared() ?? SharedModel(note: "Write a note ✨")
        completion(SimpleEntry(date: Date(), model: model))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
    let now = Date()
    let model = readShared() ?? SharedModel(note: "Write a note ✨")
    let entry = SimpleEntry(date: now, model: model)

    let next = Calendar.current.date(byAdding: .minute, value: 1, to: now)!

     completion(Timeline(entries: [entry], policy: .after(next)))
     }
    } 

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    let entry: Provider.Entry

    var text: String {
        let t = entry.model.note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Write a note ✨" : t
    }

    var body: some View {
        ZStack {
            if #available(iOSApplicationExtension 17.0, *) {
                // iOS 17+ doğru container background
                Color.clear
                    .containerBackground(for: .widget) {
                        backgroundView
                    }
            } else {
                // iOS 16 fallback
                backgroundView
            }

            contentView
                .padding(14)
        }
    }

    private var backgroundView: some View {
        let base = Color(.systemBackground)
        let card = Color(.secondarySystemBackground)

        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        card.opacity(colorScheme == .dark ? 0.9 : 1.0),
                        base.opacity(colorScheme == .dark ? 0.8 : 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12),
                    radius: 10, x: 0, y: 6)
            .padding(8)
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.system(size: family == .systemSmall ? 12 : 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(text)
                .font(.system(size: family == .systemSmall ? 17 : 19, weight: .bold))
                .foregroundStyle(Color(.label))
                .multilineTextAlignment(.leading)
                .lineLimit(family == .systemSmall ? 6 : 8)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}


struct MyHomeWidget: Widget {
    let kind = "MyHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetView(entry: entry)
        }
        .configurationDisplayName("Note Widget")
        .description("Shows your note.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
