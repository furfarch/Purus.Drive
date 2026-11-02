import Foundation
import SwiftData
import UserNotifications

/// Actions on the work-time blocks (start an activity, save, delete) and the driving reminder.
@MainActor
enum WorkLog {

    static func spans(_ blocks: [WorkBlock], now: Date = .now) -> [WorkTimeRules.Span] {
        blocks.map { .init(activity: $0.activity, start: $0.start, end: $0.end ?? now, exception: $0.exception) }
    }

    static func report(_ blocks: [WorkBlock], now: Date = .now) -> WorkTimeRules.Report {
        WorkTimeRules.evaluate(spans(blocks, now: now), now: now)
    }

    static func running(_ blocks: [WorkBlock]) -> WorkBlock? {
        blocks.filter { $0.end == nil }.max { $0.start < $1.start }
    }

    static func lastDriving(_ blocks: [WorkBlock]) -> WorkBlock? {
        blocks.filter { $0.activity == .driving }.max { $0.start < $1.start }
    }

    /// end of the last driving/work/standby block (start of the current free time)
    static func lastActiveEnd(_ blocks: [WorkBlock]) -> Date? {
        blocks.filter { $0.activity.isActive }.compactMap { $0.end ?? .now }.max()
    }

    /// The sheet asks for start time, vehicle and earlier activities when work starts after 3 h+ of free time
    /// (like inserting the driver card); after a short break the tap starts right away.
    static func needsStartSheet(_ activity: WorkActivity, blocks: [WorkBlock], now: Date = .now) -> Bool {
        guard activity.isActive else { return false }
        if activity == .driving && lastDriving(blocks) == nil { return true }
        if running(blocks)?.activity.isActive == true { return false }
        guard let free = lastActiveEnd(blocks) else { return true }
        return now.timeIntervalSince(free) >= 3 * WorkTimeRules.h
    }

    /// Ends the running block(s) at `at` and starts `activity` there.
    static func start(_ activity: WorkActivity, at: Date = .now, closeAt: Date? = nil, template: WorkBlock? = nil, blocks: [WorkBlock], context: ModelContext) {
        let closeTime = closeAt ?? at
        for b in blocks where b.end == nil {
            b.end = max(b.start, closeTime)
            b.lastEdited = .now
        }
        let new = WorkBlock(activity: activity, start: at)
        if activity == .driving {
            let source = template ?? lastDriving(blocks)
            new.vehiclePlate = source?.vehiclePlate ?? ""
            new.vehicleName = source?.vehicleName ?? ""
            new.kmStart = template?.kmStart ?? source?.kmEnd
        }
        new.placeStart = template?.placeStart ?? ""
        context.insert(new)
        save(context)
    }

    static func save(_ context: ModelContext) {
        do { try context.save() } catch { print("ERROR: failed saving work time: \(error)") }
        Task { await CloudKitSyncService.shared.pushAllToCloud() }
        refreshReminder(context)
    }

    static func delete(_ block: WorkBlock, context: ModelContext) {
        CloudKitSyncService.shared.markDeleted(entityType: "WorkBlock", id: block.id)
        context.delete(block)
        do { try context.save() } catch { print("ERROR: failed deleting work block: \(error)") }
        Task { await CloudKitSyncService.shared.pushDeletions() }
        refreshReminder(context)
    }

    // MARK: - Reminder (tachographs warn 15 min before 4 h 30 of driving)

    private static let reminderIDs = ["worktime.break.soon", "worktime.break.now"]

    static func refreshReminder(_ context: ModelContext) {
        let blocks = (try? context.fetch(FetchDescriptor<WorkBlock>())) ?? []
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: reminderIDs)
        guard running(blocks)?.activity == .driving else { return }
        let left = 4.5 * WorkTimeRules.h - report(blocks).status.drivingSinceBreak
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let soon = left - 15 * WorkTimeRules.m
            if soon > 1 { schedule(center, reminderIDs[0], after: soon, "15 min of driving left", "Plan a 45-min break (ARV 1 Art. 8).") }
            if left > 1 { schedule(center, reminderIDs[1], after: left, "4 h 30 of driving reached", "Take a 45-min break now (ARV 1 Art. 8).") }
        }
    }

    nonisolated private static func schedule(_ center: UNUserNotificationCenter, _ id: String, after: TimeInterval, _ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: after, repeats: false)))
    }
}
