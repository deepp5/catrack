import SwiftUI

struct MachineRowView: View {
    let machine: Machine
    let lastMessage: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Text(machine.model.prefix(2).uppercased())
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(machine.model)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(machine.site)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(lastMessage ?? "No messages yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(machine.hours))h")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(8)
    }
}
