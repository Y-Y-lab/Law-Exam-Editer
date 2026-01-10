import SwiftUI

@main
struct LawExamEditerApp: App {
    @StateObject private var caseStore = CaseStore()
    @StateObject private var editorState = EditorState()

    var body: some Scene {
        WindowGroup {
            AppSplitView()
                .environmentObject(caseStore)
                .environmentObject(editorState)
                .frame(minWidth: 1100, minHeight: 700)
                .onAppear {
                    caseStore.loadCases()
                }
        }
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    editorState.requestImmediateSave()
                }
                .keyboardShortcut("s")
            }
            CommandGroup(after: .find) {
                Button("Find") {
                    editorState.isFindBarVisible.toggle()
                }
                .keyboardShortcut("f")
            }
        }
    }
}

