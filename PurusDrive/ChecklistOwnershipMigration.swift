import Foundation
import SwiftData

/// Temporarily disabled: the app's model is currently running in a simplified
/// local-only configuration while CloudKit schema work is in progress.
///
/// This migration was for assigning legacy, type-only checklists to a specific
/// Vehicle or Trailer, but the current Checklist model no longer includes those
/// ownership fields.
enum ChecklistOwnershipMigration {
    static func runIfNeeded(using container: ModelContainer) {
        // no-op
    }
}
