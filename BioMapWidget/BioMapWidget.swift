import WidgetKit
import SwiftUI

struct DayEntry: TimelineEntry {
    let date: Date
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry { DayEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86400)
        completion(Timeline(entries: [DayEntry(date: now)], policy: .after(midnight)))
    }
}

private func seasonInfo(_ date: Date) -> (emoji: String, key: LocalizedStringKey) {
    switch Calendar.current.component(.month, from: date) {
    case 3, 4, 5: return ("🌸", "widget_spring")
    case 6, 7, 8: return ("🦋", "widget_summer")
    case 9, 10, 11: return ("🍄", "widget_fall")
    default: return ("🐦", "widget_winter")
    }
}

struct BioMapWidgetView: View {
    let entry: DayEntry

    private var brand: Color { Color(red: 0x19 / 255, green: 0xCE / 255, blue: 0x98 / 255) }
    private var brand2: Color { Color(red: 0, green: 0xA8 / 255, blue: 0x77 / 255) }

    var body: some View {
        let s = seasonInfo(entry.date)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s.emoji).font(.system(size: 28))
                Spacer()
                Image(systemName: "camera.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
            Text("widget_title")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(s.key)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [brand, brand2], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(URL(string: "biomap://add"))
    }
}

struct BioMapDailyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BioMapDaily", provider: DayProvider()) { entry in
            BioMapWidgetView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget_name"))
        .description(String(localized: "widget_desc"))
        .supportedFamilies([.systemSmall])
    }
}

@main
struct BioMapWidgetBundle: WidgetBundle {
    var body: some Widget {
        BioMapDailyWidget()
    }
}
