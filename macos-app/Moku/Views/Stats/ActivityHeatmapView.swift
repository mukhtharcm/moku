import SwiftUI

struct ActivityHeatmapView: View {
    let dailyMinutes: [Date: Int]

    private let calendar = Calendar.current
    private let columns = 53
    private let rows = 7

    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(columns * rows - 1), to: today)!
        return (0..<(columns * rows)).map {
            calendar.date(byAdding: .day, value: $0, to: startDate)!
        }
    }

    private var maxMinutes: Int {
        dailyMinutes.values.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reading Activity")
                .font(.headline)
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(12), spacing: 2), count: columns),
                spacing: 2
            ) {
                ForEach(days, id: \.self) { day in
                    let mins = dailyMinutes[day] ?? 0
                    let intensity = maxMinutes > 0 ? Double(mins) / Double(maxMinutes) : 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cellColor(intensity: intensity))
                        .frame(width: 12, height: 12)
                        .help(tooltipText(day: day, minutes: mins))
                }
            }
            HStack {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cellColor(intensity: intensity))
                        .frame(width: 12, height: 12)
                }
                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cellColor(intensity: Double) -> Color {
        if intensity == 0 { return Color.secondary.opacity(0.15) }
        return Color.orange.opacity(0.2 + intensity * 0.8)
    }

    private func tooltipText(day: Date, minutes: Int) -> String {
        let formatted = DateFormatter.localizedString(from: day, dateStyle: .medium, timeStyle: .none)
        if minutes == 0 { return "\(formatted): No reading" }
        return "\(formatted): \(minutes) min"
    }
}
