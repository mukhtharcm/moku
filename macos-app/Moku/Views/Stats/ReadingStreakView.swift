import SwiftUI

struct ReadingStreakView: View {
    let current: Int
    let longest: Int

    var body: some View {
        HStack(spacing: 24) {
            streakCard(value: current, label: "Current Streak", icon: "flame.fill", color: .orange)
            Divider().frame(height: 44)
            streakCard(value: longest, label: "Longest Streak", icon: "trophy.fill", color: .yellow)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func streakCard(value: Int, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(value > 0 ? color : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
