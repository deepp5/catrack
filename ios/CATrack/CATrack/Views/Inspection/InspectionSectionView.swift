import SwiftUI

struct InspectionSectionView: View {
    let machineId: UUID
    @Binding var section: InspectionSection
    @EnvironmentObject var sheetVM: InspectionSheetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))

            ForEach($section.fields) { $field in
                InspectionFieldRow(machineId: machineId, sectionId: section.id, field: $field)
                    .padding(.horizontal, 16)
                Divider()
                    .padding(.leading, 16)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
