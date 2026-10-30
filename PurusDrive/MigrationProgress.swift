import Foundation
import SwiftUI
import Combine

@MainActor
final class MigrationProgress: ObservableObject {
    enum State {
        case idle
        case running(title: String, message: String?) // used for both migration and sync
        case success(message: String?)
    }

    @Published var state: State = .idle
    private var hideTask: Task<Void, Never>?

    var isVisible: Bool {
        switch state {
        case .idle: return false
        default: return true
        }
    }

    func start(title: String, message: String? = nil) {
        // a pending auto-hide from the last run would hide this one
        hideTask?.cancel()
        withAnimation { state = .running(title: title, message: message) }
    }

    func update(message: String?) {
        switch state {
        case .running(let title, _):
            withAnimation { state = .running(title: title, message: message) }
        default:
            break
        }
    }

    func succeed(message: String? = nil) {
        withAnimation { state = .success(message: message) }
        // Auto-hide after a short delay
        hideTask?.cancel()
        hideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation { self.state = .idle }
        }
    }
}
