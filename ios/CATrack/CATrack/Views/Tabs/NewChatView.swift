import SwiftUI

struct NewChatView: View {
    @EnvironmentObject var machineVM: MachineViewModel
    @EnvironmentObject var chatVM: ChatViewModel

    @State private var showAddMachine = false
    @State private var newModel = ""
    @State private var newSerial = ""
    @State private var newHours = ""
    @State private var newSite = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Machine quick-select horizontal scroll
                if !machineVM.machines.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(machineVM.machines) { machine in
                                Button {
                                    machineVM.selectMachine(machine)
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(machineVM.selectedMachine?.id == machine.id
                                                      ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                                      : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 52, height: 52)
                                            Text(machine.model.prefix(2).uppercased())
                                                .font(.headline.bold())
                                                .foregroundStyle(.white)
                                        }
                                        Text(machine.model)
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .frame(width: 60)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    Divider()
                }

                // Main content
                if let machine = machineVM.selectedMachine {
                    ActiveChatView(machine: machine)
                } else {
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))

                        Text("Start New Inspection")
                            .font(.title2.bold())

                        Text("Add a machine to begin an AI-powered inspection session.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 32)

                        Button("Add New Machine") {
                            showAddMachine = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        Spacer()
                    }
                }
            }
            .navigationTitle("New Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddMachine = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddMachine) {
                addMachineSheet
            }
        }
    }

    private var addMachineSheet: some View {
        NavigationStack {
            Form {
                Section("Machine Details") {
                    TextField("Model (e.g. CAT 320)", text: $newModel)
                    TextField("Serial Number", text: $newSerial)
                    TextField("Hours", text: $newHours)
                        .keyboardType(.decimalPad)
                    TextField("Site", text: $newSite)
                }
            }
            .navigationTitle("Add Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddMachine = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let machine = Machine(
                            model: newModel.isEmpty ? "Unknown Model" : newModel,
                            serialNumber: newSerial,
                            hours: Double(newHours) ?? 0,
                            site: newSite.isEmpty ? "Unknown Site" : newSite
                        )
                        machineVM.addMachine(machine)
                        machineVM.selectMachine(machine)
                        newModel = ""; newSerial = ""; newHours = ""; newSite = ""
                        showAddMachine = false
                    }
                }
            }
        }
    }
}
