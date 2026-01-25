import Foundation

enum ChecklistTitle {
    /// Format: Checklist "Vehicle Type" YYYY-MM-DD HH:MM (24h)
    static func make(for vehicleType: VehicleType, date: Date = .now) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return "Checklist \(vehicleType.displayName) \(df.string(from: date))"
    }
}
