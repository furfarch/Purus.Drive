import Foundation
import Combine

struct SyncReport: Codable {
    var startedAt: Date
    var finishedAt: Date?
    var mode: String // "iCloud" or "Local"
    var pushed: [String: Int] = [:] // recordType -> count
    var fetched: [String: Int] = [:]
    var error: String?
}

@MainActor
final class SyncReportStore: ObservableObject {
    static let shared = SyncReportStore()
    @Published var lastReport: SyncReport? = nil

    private init() {}
}
