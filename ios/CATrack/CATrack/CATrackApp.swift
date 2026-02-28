//
//  CATrackApp.swift
//  CATrack
//
//  Created by Deep Patel on 2/28/26.
//

import SwiftUI

@main
struct CATrackApp: App {
    @StateObject private var machineVM = MachineViewModel()
    @StateObject private var chatVM = ChatViewModel()
    @StateObject private var sheetVM = InspectionSheetViewModel()
    @StateObject private var completedVM = CompletedInspectionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(machineVM)
                .environmentObject(chatVM)
                .environmentObject(sheetVM)
                .environmentObject(completedVM)
        }
    }
}
