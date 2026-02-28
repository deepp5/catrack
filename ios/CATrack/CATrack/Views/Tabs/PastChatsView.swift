import SwiftUI

struct PastChatsView: View {
    @EnvironmentObject var machineVM: MachineViewModel
    @EnvironmentObject var chatVM: ChatViewModel

    var body: some View {
        NavigationStack {
            Group {
                if machineVM.machines.isEmpty {
                    ContentUnavailableView("No Chats Yet", systemImage: "bubble.left.and.bubble.right", description: Text("Start a new inspection to begin chatting."))
                } else {
                    List {
                        ForEach(machineVM.machines) { machine in
                            let lastMsg = chatVM.sessions[machine.id]?.last?.text
                            Button {
                                machineVM.selectMachine(machine)
                            } label: {
                                MachineRowView(
                                    machine: machine,
                                    lastMessage: lastMsg,
                                    isSelected: machineVM.selectedMachine?.id == machine.id
                                )
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Chats")
        }
    }
}
