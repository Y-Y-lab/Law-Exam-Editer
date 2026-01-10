import SwiftUI

struct EditorPane: View {
    @EnvironmentObject private var caseStore: CaseStore
    @EnvironmentObject private var editorState: EditorState

    var body: some View {
        VStack(spacing: 0) {
            if editorState.isFindBarVisible {
                FindBar()
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.windowBackgroundColor))
            }
            EditorTextView(
                text: $caseStore.editorText,
                findQuery: $editorState.findQuery,
                findStatusMessage: $editorState.findStatusMessage,
                findAction: editorState.findAction,
                onTextChange: {
                    caseStore.scheduleSave()
                }
            )
            .background(Color(NSColor.textBackgroundColor))

            HStack {
                Text("Characters: \(caseStore.editorText.count)")
                    .font(.caption)
                Spacer()
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onReceive(editorState.immediateSavePublisher) { _ in
            caseStore.immediateSave()
        }
        .alert("Error", isPresented: Binding(get: {
            caseStore.errorMessage != nil
        }, set: { _ in
            caseStore.clearError()
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(caseStore.errorMessage ?? "Unknown error")
        }
        .overlay(alignment: .top) {
            if caseStore.needsMetaRepair {
                HStack {
                    Text("meta.json appears corrupted.")
                    Button("Repair") {
                        caseStore.repairMeta()
                    }
                }
                .padding(8)
                .background(Color(NSColor.systemRed).opacity(0.1))
            }
        }
    }
}

private struct FindBar: View {
    @EnvironmentObject private var editorState: EditorState

    var body: some View {
        HStack {
            TextField("Find", text: $editorState.findQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 220)
            Button("Previous") {
                editorState.triggerFindAction(.previous)
            }
            Button("Next") {
                editorState.triggerFindAction(.next)
            }
            if let message = editorState.findStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Close") {
                editorState.isFindBarVisible = false
                editorState.triggerFindAction(.close)
            }
        }
    }
}

