import SwiftUI

struct InspectionFieldRow: View {
    let machineId: UUID
    let sectionId: UUID
    @Binding var field: InspectionField
    @EnvironmentObject var sheetVM: InspectionSheetViewModel

    var severityColor: Color {
        switch field.severity {
        case .pass: return .green
        case .monitor: return .orange
        case .fail: return .red
        case nil: return .clear
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            if field.severity != nil {
                Circle()
                    .fill(severityColor)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(field.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Enter value...", text: $field.value)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onChange(of: field.value) { _, newValue in
                        sheetVM.updateField(machineId: machineId, sectionId: sectionId, fieldId: field.id, value: newValue)
                    }
            }
        }
        .padding(.vertical, 4)
    }
}
