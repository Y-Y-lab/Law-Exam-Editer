import Foundation

struct CaseMeta: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var goodnotesURL: String
    var activeEditor: String

    static func empty(title: String) -> CaseMeta {
        let now = Date()
        return CaseMeta(
            id: UUID(),
            title: title,
            createdAt: now,
            updatedAt: now,
            goodnotesURL: "",
            activeEditor: "draft.md"
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case goodnotesURL = "goodnotes_url"
        case activeEditor = "active_editor"
    }
}

struct CaseEntry: Identifiable, Hashable {
    let id: UUID
    var meta: CaseMeta
    var folderURL: URL
}

enum CaseFile: String, CaseIterable, Identifiable {
    case draft = "draft.md"
    case notes = "notes.md"

    var id: String { rawValue }
}

