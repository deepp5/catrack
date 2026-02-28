import Foundation
import Combine

@MainActor
class CompletedInspectionViewModel: ObservableObject {
    @Published var completedInspections: [CompletedInspection] = []

    func addCompleted(_ inspection: CompletedInspection) {
        completedInspections.insert(inspection, at: 0)
    }
}
