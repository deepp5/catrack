import SwiftUI

struct InspectionSheetView: View {
    @EnvironmentObject var machineVM: MachineViewModel
    @EnvironmentObject var sheetVM: InspectionSheetViewModel
    @EnvironmentObject var completedVM: CompletedInspectionViewModel
    @EnvironmentObject var chatVM: ChatViewModel

    var body: some View {
        NavigationStack {
            Group {
                if let machine = machineVM.selectedMachine {
                    sheetContent(for: machine)
                        .onAppear {
                            _ = sheetVM.getOrCreateSheet(for: machine.id)
                        }
                } else {
                    ContentUnavailableView(
                        "No Machine Selected",
                        systemImage: "doc.text",
                        description: Text("Select or create a machine in the New tab.")
                    )
                }
            }
            .navigationTitle("Inspection Sheet")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func sheetContent(for machine: Machine) -> some View {
        if sheetVM.sheets[machine.id]?.isFinalized == true {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("Inspection Finalized")
                    .font(.title2.bold())
                if let name = sheetVM.sheets[machine.id]?.templateName {
                    Text(name)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    if let templateName = sheetVM.sheets[machine.id]?.templateName {
                        Text(templateName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }

                    if let sections = sheetVM.sheets[machine.id]?.sections {
                        ForEach(sections.indices, id: \.self) { sIdx in
                            InspectionSectionView(
                                machineId: machine.id,
                                section: Binding(
                                    get: { sheetVM.sheets[machine.id]?.sections[sIdx] ?? sections[sIdx] },
                                    set: { sheetVM.sheets[machine.id]?.sections[sIdx] = $0 }
                                )
                            )
                            .padding(.horizontal, 16)
                        }
                    }

                    Button("Finalize Inspection") {
                        finalizeInspection(machine: machine)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .padding(.top, 12)
            }
        }
    }

    private func finalizeInspection(machine: Machine) {
        sheetVM.finalizeSheet(for: machine.id)
        guard let sheet = sheetVM.sheets[machine.id] else { return }
        let allFindings = chatVM.sessions[machine.id]?.compactMap { $0.findings }.flatMap { $0 } ?? []
        let inspection = CompletedInspection(
            machine: machine,
            sheet: sheet,
            allFindings: allFindings,
            summary: "Inspection completed for \(machine.model) at \(machine.site).",
            overallRisk: overallRisk(from: allFindings)
        )
        completedVM.addCompleted(inspection)
    }

    private func overallRisk(from findings: [Finding]) -> OverallRisk {
        if findings.contains(where: { $0.severity == .fail }) { return .critical }
        if findings.contains(where: { $0.severity == .monitor }) { return .medium }
        return .low
    }
}
