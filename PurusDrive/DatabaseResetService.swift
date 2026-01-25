import Foundation
import UIKit

enum DatabaseResetService {
    /// Deletes the app's Application Support directory (where SwiftData/CoreData stores live).
    ///
    /// This is an aggressive reset. After this, the app should be terminated and relaunched.
    static func resetApplicationSupport() throws {
        let fm = FileManager.default

        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "DatabaseResetService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not locate Application Support directory."])
        }

        if fm.fileExists(atPath: appSupport.path) {
            try fm.removeItem(at: appSupport)
        }

        try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
    }

    /// Terminates the app process so it can be relaunched and the ModelContainer rebuilt.
    ///
    /// Apple doesn't provide a sanctioned "restart app" API; exiting is the only reliable way.
    static func terminateForRelaunch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            exit(0)
        }
    }
}
