import SwiftUI

struct CaseOrganizerPane: View {
    @EnvironmentObject private var caseStore: CaseStore

    @State private var isCreateSheetPresented = false
    @State private var isRenameSheetPresented = false
    @State private var newCaseTitle = ""
    @State private var renameTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cases")
                    .font(.headline)
                Spacer()
                Button("New") {
                    newCaseTitle = ""
                    isCreateSheetPresented = true
                }
                Button("Rename") {
                    if let selected = caseStore.cases.first(where: { $0.id == caseStore.selectedCaseID }) {
                        renameTitle = selected.meta.title
                        isRenameSheetPresented = true
                    }
                }
                .disabled(caseStore.selectedCaseID == nil)
                Button("Delete") {
                    if let id = caseStore.selectedCaseID {
                        caseStore.deleteCase(id: id)
                    }
                }
                .disabled(caseStore.selectedCaseID == nil)
            }

            List(selection: Binding(get: {
                caseStore.selectedCaseID
            }, set: { newValue in
                if let id = newValue {
                    caseStore.selectCase(id: id)
                }
            })) {
                ForEach(caseStore.cases, id: \.id) { entry in
                    Text(entry.meta.title)
                        .tag(entry.id)
                }
            }
            .frame(minHeight: 120)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Files")
                    .font(.headline)
                ForEach(CaseFile.allCases) { file in
                    Button(file.rawValue) {
                        caseStore.selectFile(file)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(caseStore.selectedFile == file ? .accentColor : .primary)
                }
                AttachmentList(caseStore: caseStore)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Goodnotes URL")
                    .font(.headline)
                TextField("https://", text: Binding(get: {
                    caseStore.cases.first(where: { $0.id == caseStore.selectedCaseID })?.meta.goodnotesURL ?? ""
                }, set: { newValue in
                    caseStore.updateGoodnotesURL(newValue)
                }))
                .textFieldStyle(RoundedBorderTextFieldStyle())

                HStack {
                    Button("Load") {
                        NotificationCenter.default.post(name: .goodnotesLoadRequested, object: nil)
                    }
                    Button("Clear") {
                        caseStore.updateGoodnotesURL("")
                        NotificationCenter.default.post(name: .goodnotesLoadRequested, object: nil)
                    }
                }
            }
            Spacer()
        }
        .padding(12)
        .sheet(isPresented: $isCreateSheetPresented) {
            CaseTitleSheet(title: "Create Case", value: $newCaseTitle) {
                caseStore.createCase(title: newCaseTitle.isEmpty ? "Untitled" : newCaseTitle)
                isCreateSheetPresented = false
            }
        }
        .sheet(isPresented: $isRenameSheetPresented) {
            CaseTitleSheet(title: "Rename Case", value: $renameTitle) {
                if let id = caseStore.selectedCaseID {
                    caseStore.renameCase(id: id, title: renameTitle.isEmpty ? "Untitled" : renameTitle)
                }
                isRenameSheetPresented = false
            }
        }
    }
}

private struct CaseTitleSheet: View {
    let title: String
    @Binding var value: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline)
            TextField("Title", text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 280)
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    onSave()
                    dismiss()
                }
            }
        }
        .padding(20)
    }
}

private struct AttachmentList: View {
    let caseStore: CaseStore

    var body: some View {
        if let folderURL = caseStore.cases.first(where: { $0.id == caseStore.selectedCaseID })?.folderURL {
            let attachmentsURL = folderURL.appendingPathComponent("attachments")
            if let items = try? FileManager.default.contentsOfDirectory(at: attachmentsURL, includingPropertiesForKeys: nil) {
                if !items.isEmpty {
                    Text("Attachments")
                        .font(.headline)
                    ForEach(items, id: \.self) { item in
                        Button(item.lastPathComponent) {
                            NSWorkspace.shared.open(item)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let goodnotesLoadRequested = Notification.Name("goodnotes.load.requested")
}

