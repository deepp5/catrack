import SwiftUI

@main
struct CATrackApp: App {
    
    @StateObject private var machineStore = MachineStore()
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var sheetVM = InspectionSheetViewModel()
    @StateObject private var archiveStore = ArchiveStore()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(machineStore)
                .environmentObject(chatVM)
                .environmentObject(sheetVM)
                .environmentObject(archiveStore)
                .environmentObject(settingsStore)
                .preferredColorScheme(.dark)
        }
    }
}
