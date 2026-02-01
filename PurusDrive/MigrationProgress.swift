import Foundation
import SwiftUI
import Combine

@MainActor
final class MigrationProgress: ObservableObject {
    enum State {
        case idle
        case running(title: String, message: String?) // used for both migration and sync
        case success(message: String?)
        case failure(error: String)
    }

    @Published var state: State = .idle

    var isVisible: Bool {
        switch state {
        case .idle: return false
        default: return true
        }
    }

    func start(title: String, message: String? = nil) {
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
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation { self.state = .idle }
        }
    }

    func fail(error: String) {
        withAnimation { state = .failure(error: error) }
        // Auto-hide after a longer delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation { self.state = .idle }
        }
    }
}
