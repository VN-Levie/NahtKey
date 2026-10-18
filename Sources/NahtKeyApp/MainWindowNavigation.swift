import Combine
import Foundation

enum MainTab: Hashable { case dictionary, lab, settings }

struct CorrectionEditorTarget: Identifiable {
    let id = UUID()
    let entry: CorrectionEntry?
}

@MainActor
final class MainWindowNavigation: ObservableObject {
    @Published var selectedTab: MainTab = .dictionary
    @Published var editor: CorrectionEditorTarget?

    func addWord() {
        selectedTab = .dictionary
        // Reopening from the menu must never discard an unfinished add/edit form.
        if editor == nil { editor = CorrectionEditorTarget(entry: nil) }
    }
}
