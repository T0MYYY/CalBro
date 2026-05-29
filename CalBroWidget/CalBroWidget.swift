import WidgetKit
import SwiftUI

// MARK: - Palette (self-contained; mirrors the app's terra/plum/ocean/gold)

private enum WColors {
    static let terra = Color(red: 0.85, green: 0.45, blue: 0.32)
    static let plum  = Color(red: 0.55, green: 0.40, blue: 0.62)
    static let ocean = Color(red: 0.30, green: 0.55, blue: 0.70)
    static let gold  = Color(red: 0.82, green: 0.64, blue: 0.30)
    static let card  = Color(red: 0.067, green: 0.094, blue: 0.157) // 0x111828
}

// MARK: - Timeline

struct NutritionEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetNutritionSnapshot
}

struct NutritionProvider: TimelineProvider {
    func placeholder(in context: Context) -> NutritionEntry {
        NutritionEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (NutritionEntry) -> Void) {
        let snap = context.isPreview ? .placeholder : SharedNutritionStore.load()
        completion(NutritionEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutritionEntry>) -> Void) {
        let entry = NutritionEntry(date: Date(), snapshot: SharedNutritionStore.load())
        // Refresh hourly as a fallback; the app also reloads on every meal change.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct CalBroWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NutritionEntry

    var body: some View {
        switch family {
        case .accessoryCircular:   circular
        case .accessoryRectangular: rectangular
        case .systemSmall:         small
        default:                   medium
        }
    }

    private var snap: WidgetNutritionSnapshot { entry.snapshot }

    // Lock screen — circular ring
    private var circular: some View {
        Gauge(value: snap.progress) {
            Text("kcal")
        } currentValueLabel: {
            Text("\(snap.caloriesConsumed)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(.clear, for: .widget)
    }

    // Lock screen — rectangular
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(snap.caloriesConsumed) / \(snap.calorieTarget) kcal")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            ProgressView(value: snap.progress)
                .tint(.primary)
            Text("\(snap.remaining) kcal left · P\(snap.protein) C\(snap.carbs) F\(snap.fat)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .containerBackground(.clear, for: .widget)
    }

    // Home — small
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: snap.progress)
                    .stroke(WColors.terra, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(snap.caloriesConsumed)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("kcal").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                }
            }
            Text("\(snap.remaining) left")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(WColors.card, for: .widget)
    }

    // Home — medium
    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Today").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                Text("\(snap.caloriesConsumed)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(snap.remaining) kcal left")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    macroPill("P", "\(snap.protein)g", WColors.plum)
                    macroPill("C", "\(snap.carbs)g", WColors.ocean)
                    macroPill("F", "\(snap.fat)g", WColors.gold)
                }
            }
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: snap.progress)
                    .stroke(WColors.terra, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((snap.progress * 100).rounded()))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 84, height: 84)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(WColors.card, for: .widget)
    }

    private func macroPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(color.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Widget declaration

struct CalBroWidget: Widget {
    let kind = "CalBroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionProvider()) { entry in
            CalBroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CalBro")
        .description("Today's calories and macros at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular
        ])
    }
}

@main
struct CalBroWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalBroWidget()
    }
}
