import Foundation
import SwiftUI

@MainActor
final class CaseStore: ObservableObject {
    @Published var cases: [CaseEntry] = []
    @Published var selectedCaseID: UUID?
    @Published var selectedFile: CaseFile = .draft
    @Published var editorText: String = ""
    @Published var errorMessage: String?
    @Published var needsMetaRepair = false

    private let ioQueue = DispatchQueue(label: "CaseStore.IO", qos: .userInitiated)
    private let saveDebouncer = Debouncer(interval: 1.2, queue: .main)

    private var currentCaseURL: URL? {
        guard let caseID = selectedCaseID else { return nil }
        return cases.first(where: { $0.id == caseID })?.folderURL
    }

    private var rootURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Documents/ShihouDraft", isDirectory: true)
    }

    private var casesURL: URL {
        rootURL.appendingPathComponent("Cases", isDirectory: true)
    }

    func loadCases() {
        ioQueue.async {
            do {
                try FileIO.ensureDirectory(self.casesURL)
                let contents = try FileManager.default.contentsOfDirectory(at: self.casesURL, includingPropertiesForKeys: nil)
                let entries = try contents.compactMap { folderURL -> CaseEntry? in
                    let metaURL = folderURL.appendingPathComponent("meta.json")
                    guard FileManager.default.fileExists(atPath: metaURL.path) else { return nil }
                    do {
                        let meta = try FileIO.readJSON(CaseMeta.self, from: metaURL)
                        return CaseEntry(id: meta.id, meta: meta, folderURL: folderURL)
                    } catch {
                        let fallbackID = UUID(uuidString: folderURL.lastPathComponent) ?? UUID()
                        let fallbackMeta = CaseMeta(
                            id: fallbackID,
                            title: "Corrupted Case",
                            createdAt: Date(),
                            updatedAt: Date(),
                            goodnotesURL: "",
                            activeEditor: "draft.md"
                        )
                        DispatchQueue.main.async {
                            self.needsMetaRepair = true
                        }
                        return CaseEntry(id: fallbackID, meta: fallbackMeta, folderURL: folderURL)
                    }
                }
                DispatchQueue.main.async {
                    self.cases = entries.sorted { $0.meta.createdAt < $1.meta.createdAt }
                    if self.selectedCaseID == nil {
                        self.selectedCaseID = self.cases.first?.id
                    }
                    self.syncSelectedFileFromMeta()
                    self.loadEditorText()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func createCase(title: String) {
        ioQueue.async {
            do {
                try FileIO.ensureDirectory(self.casesURL)
                var meta = CaseMeta.empty(title: title)
                let caseFolder = self.casesURL.appendingPathComponent(meta.id.uuidString, isDirectory: true)
                try FileIO.ensureDirectory(caseFolder)
                let attachments = caseFolder.appendingPathComponent("attachments", isDirectory: true)
                try FileIO.ensureDirectory(attachments)
                try FileIO.atomicWrite(text: "", to: caseFolder.appendingPathComponent("draft.md"))
                try FileIO.atomicWrite(text: "", to: caseFolder.appendingPathComponent("notes.md"))
                try FileIO.writeJSON(meta, to: caseFolder.appendingPathComponent("meta.json"))
                let entry = CaseEntry(id: meta.id, meta: meta, folderURL: caseFolder)
                DispatchQueue.main.async {
                    self.cases.append(entry)
                    self.selectedCaseID = entry.id
                    self.selectedFile = .draft
                    self.editorText = ""
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func renameCase(id: UUID, title: String) {
        guard let index = cases.firstIndex(where: { $0.id == id }) else { return }
        var entry = cases[index]
        entry.meta.title = title
        entry.meta.updatedAt = Date()
        updateMeta(entry)
    }

    func deleteCase(id: UUID) {
        guard let entry = cases.first(where: { $0.id == id }) else { return }
        ioQueue.async {
            do {
                try FileManager.default.trashItem(at: entry.folderURL, resultingItemURL: nil)
                DispatchQueue.main.async {
                    self.cases.removeAll { $0.id == id }
                    if self.selectedCaseID == id {
                        self.selectedCaseID = self.cases.first?.id
                        self.syncSelectedFileFromMeta()
                        self.loadEditorText()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func selectCase(id: UUID) {
        immediateSave()
        selectedCaseID = id
        syncSelectedFileFromMeta()
        loadEditorText()
    }

    func selectFile(_ file: CaseFile) {
        immediateSave()
        selectedFile = file
        updateActiveEditor(file)
        loadEditorText()
    }

    func updateGoodnotesURL(_ url: String) {
        guard let entry = currentEntry() else { return }
        var updated = entry
        updated.meta.goodnotesURL = url
        updated.meta.updatedAt = Date()
        updateMeta(updated)
    }

    func clearError() {
        errorMessage = nil
    }

    func scheduleSave() {
        saveDebouncer.schedule { [weak self] in
            self?.saveCurrentFile()
        }
    }

    func immediateSave() {
        saveDebouncer.cancel()
        saveCurrentFile()
    }

    func loadEditorText() {
        guard let caseURL = currentCaseURL else {
            editorText = ""
            return
        }
        let fileURL = caseURL.appendingPathComponent(selectedFile.rawValue)
        ioQueue.async {
            do {
                let text = try FileIO.readText(from: fileURL)
                DispatchQueue.main.async {
                    self.editorText = text
                }
            } catch {
                DispatchQueue.main.async {
                    self.editorText = ""
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func saveCurrentFile() {
        guard let caseURL = currentCaseURL else { return }
        let textToSave = editorText
        let fileURL = caseURL.appendingPathComponent(selectedFile.rawValue)
        ioQueue.async {
            do {
                try FileIO.atomicWrite(text: textToSave, to: fileURL)
                self.touchUpdatedAt()
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func repairMeta() {
        guard let caseURL = currentCaseURL else { return }
        ioQueue.async {
            do {
                let id = self.selectedCaseID ?? UUID()
                let meta = CaseMeta(
                    id: id,
                    title: "Recovered Case",
                    createdAt: Date(),
                    updatedAt: Date(),
                    goodnotesURL: "",
                    activeEditor: "draft.md"
                )
                try FileIO.writeJSON(meta, to: caseURL.appendingPathComponent("meta.json"))
                DispatchQueue.main.async {
                    self.needsMetaRepair = false
                    self.loadCases()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func syncSelectedFileFromMeta() {
        guard let entry = currentEntry() else { return }
        if let file = CaseFile(rawValue: entry.meta.activeEditor) {
            selectedFile = file
        } else {
            selectedFile = .draft
        }
    }

    private func updateActiveEditor(_ file: CaseFile) {
        guard let entry = currentEntry() else { return }
        var updated = entry
        updated.meta.activeEditor = file.rawValue
        updated.meta.updatedAt = Date()
        updateMeta(updated)
    }

    private func currentEntry() -> CaseEntry? {
        guard let id = selectedCaseID else { return nil }
        return cases.first(where: { $0.id == id })
    }

    private func updateMeta(_ entry: CaseEntry) {
        ioQueue.async {
            do {
                try FileIO.writeJSON(entry.meta, to: entry.folderURL.appendingPathComponent("meta.json"))
                DispatchQueue.main.async {
                    if let index = self.cases.firstIndex(where: { $0.id == entry.id }) {
                        self.cases[index] = entry
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if case FileIOError.invalidJSON = error {
                        self.needsMetaRepair = true
                    }
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func touchUpdatedAt() {
        guard let entry = currentEntry() else { return }
        var updated = entry
        updated.meta.updatedAt = Date()
        updateMeta(updated)
    }
}
