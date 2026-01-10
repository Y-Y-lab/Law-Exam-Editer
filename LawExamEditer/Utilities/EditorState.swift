import Foundation
import Combine

enum FindActionType {
    case next
    case previous
    case close
}

struct FindAction: Equatable {
    let id = UUID()
    let type: FindActionType
}

final class EditorState: ObservableObject {
    @Published var isFindBarVisible = false
    @Published var findQuery = ""
    @Published var findStatusMessage: String?
    @Published var findAction: FindAction?

    private let immediateSaveSubject = PassthroughSubject<Void, Never>()

    var immediateSavePublisher: AnyPublisher<Void, Never> {
        immediateSaveSubject.eraseToAnyPublisher()
    }

    func requestImmediateSave() {
        immediateSaveSubject.send()
    }

    func triggerFindAction(_ type: FindActionType) {
        findAction = FindAction(type: type)
    }
}

