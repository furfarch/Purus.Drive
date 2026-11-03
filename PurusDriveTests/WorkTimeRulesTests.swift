import Testing
import Foundation
@testable import PurusDrive

/// ARV 1 checks on hand-built days (UTC, week starts Monday 2 Nov 2026).
struct WorkTimeRulesTests {
    typealias R = WorkTimeRules
    let h = R.h, m = R.m
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    var monday: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 2))! }

    /// sequence of (activity, minutes) from a start; rest entries become gaps
    func day(_ start: Date, _ parts: [(WorkActivity, Double)], exception: Bool = false) -> [R.Span] {
        var t = start, out: [R.Span] = []
        for (a, mins) in parts {
            let end = t.addingTimeInterval(mins * m)
            if a.isActive { out.append(.init(activity: a, start: t, end: end, exception: exception)) }
            t = end
        }
        return out
    }

    func run(_ spans: [R.Span], now: Date? = nil) -> R.Report {
        R.evaluate(spans, now: now ?? spans.map(\.end).max()!.addingTimeInterval(12 * h), calendar: cal)
    }

    func has(_ r: R.Report, _ art: String) -> Bool { r.findings.contains { $0.article == art } }

    @Test func drivingOverFourAndHalfHoursWithoutBreakIsFlagged() {
        let r = run(day(monday.addingTimeInterval(6 * h), [(.driving, 280)]))
        #expect(has(r, "Art. 8.1"))
    }

    @Test func splitBreakFifteenThenThirtyResetsDriving() {
        let r = run(day(monday.addingTimeInterval(6 * h), [(.driving, 120), (.rest, 15), (.driving, 120), (.rest, 30), (.driving, 120)]))
        #expect(!has(r, "Art. 8.1"))
    }

    @Test func thirtyThenFifteenDoesNotReset() {
        let r = run(day(monday.addingTimeInterval(6 * h), [(.driving, 120), (.rest, 30), (.driving, 120), (.rest, 15), (.driving, 60)]))
        #expect(has(r, "Art. 8.1"))
    }

    @Test func dailyRestKinds() {
        let d1 = day(monday.addingTimeInterval(6 * h), [(.work, 120)])            // 06–08
        let regular = run(d1 + day(monday.addingTimeInterval(19 * h), [(.work, 60)]))     // rest 11 h
        #expect(regular.shifts[0].restAfter?.kind == .dailyRegular)
        let reduced = run(d1 + day(monday.addingTimeInterval(17.5 * h), [(.work, 60)]))   // rest 9.5 h
        #expect(reduced.shifts[0].restAfter?.kind == .dailyReduced)
        // 06:00 start, work until 21:00, rest only 9 h of which 9 h fall in the 24 h → reduced; until 22:00 → 8 h → too short
        let late = run(day(monday.addingTimeInterval(6 * h), [(.work, 16 * 60)]) + day(monday.addingTimeInterval(32 * h), [(.work, 60)]))
        #expect(late.shifts[0].restAfter?.kind == .tooShort)
        #expect(has(late, "Art. 9.1–9.2"))
    }

    @Test func splitDailyRestThreePlusNine() {
        let spans = day(monday.addingTimeInterval(6 * h), [(.work, 120), (.rest, 180), (.work, 240)]) + day(monday.addingTimeInterval(24 * h), [(.work, 60)])
        let r = run(spans)
        #expect(r.shifts[0].splitPart == 3 * h)
        #expect(r.shifts[0].restAfter?.kind == .dailySplit)
    }

    @Test func shortBreaksCountAsWorkAndSixHoursNeedABreak() {
        let r = run(day(monday.addingTimeInterval(6 * h), [(.work, 180), (.rest, 10), (.work, 190)]))
        #expect(r.shifts[0].work == 380 * m)
        #expect(has(r, "Art. 8.3"))
    }

    @Test func overTenHoursDrivingIsFlaggedUnlessArt12Exception() {
        let parts: [(WorkActivity, Double)] = [(.driving, 240), (.rest, 45), (.driving, 240), (.rest, 45), (.driving, 150)]   // 10.5 h
        let plain = run(day(monday.addingTimeInterval(5 * h), parts))
        #expect(has(plain, "Art. 5.1"))
        let exc = run(day(monday.addingTimeInterval(5 * h), parts, exception: true), now: monday.addingTimeInterval(24 * h))
        #expect(!has(exc, "Art. 5.1"))
        #expect(exc.status.openOwed.first.map { abs($0.hours - 0.5) < 0.01 } == true)
    }

    @Test func weeklyDrivingAndWorkLimits() {
        var spans: [R.Span] = []
        for d in 0..<7 {   // 7 × 9 h driving = 63 h
            spans += day(monday.addingTimeInterval(Double(d) * 24 * h + 5 * h), [(.driving, 270), (.rest, 45), (.driving, 270)])
        }
        let r = run(spans)
        #expect(has(r, "Art. 5.2"))
        #expect(has(r, "Art. 6.1"))
        #expect(has(r, "Art. 11.3") == false)   // no weekly rest at all in the data yet
    }

    @Test func weeklyRestTooLateAndReducedRestOwed() {
        // reduced weekly rest of 30 h, then 7 working days, then a weekly rest of exactly 45 h (no extra to make up the 15 h)
        var spans = day(monday.addingTimeInterval(6 * h), [(.work, 60)])
        var t = monday.addingTimeInterval(7 * h + 30 * h)
        for _ in 0..<7 { spans += day(t, [(.work, 120)]); t = t.addingTimeInterval(24 * h) }
        spans += day(t.addingTimeInterval(23 * h), [(.work, 60)])
        let r = run(spans, now: t.addingTimeInterval(30 * h))
        #expect(has(r, "Art. 11.3"))
        #expect(r.status.openOwed.contains { $0.reason == "Reduced weekly rest" && abs($0.hours - 15) < 0.01 })
    }

    @Test func reducedWeeklyRestMadeUpByLongerRest() {
        var spans = day(monday.addingTimeInterval(6 * h), [(.work, 60)])
        spans += day(monday.addingTimeInterval(7 * h + 30 * h), [(.work, 60)])              // 30 h rest → owes 15 h
        spans += day(monday.addingTimeInterval(38 * h + 60 * h), [(.work, 60)])             // 60 h rest → 15 h extra
        let r = run(spans, now: monday.addingTimeInterval(200 * h))
        #expect(r.status.openOwed.isEmpty)
        #expect(!r.findings.contains { $0.text.contains("not made up") })
    }

    @Test func ongoingWorkShowsLiveStatus() {
        let start = monday.addingTimeInterval(6 * h)
        let spans = [R.Span(activity: .driving, start: start, end: start.addingTimeInterval(3 * h))]
        let r = R.evaluate(spans, now: start.addingTimeInterval(3 * h), calendar: cal)
        #expect(r.status.drivingSinceBreak == 3 * h)
        #expect(r.status.dailyRestBy == start.addingTimeInterval(13 * h))
    }

    /// Art. 11d: 11 h rest on a ferry with two short interruptions (40 min in total) is a regular daily rest
    @Test func ferryRestWithTwoShortInterruptionsIsRegular() {
        let start = monday.addingTimeInterval(6 * h)
        var spans = day(start, [(.driving, 240), (.rest, 300), (.work, 20), (.rest, 200), (.driving, 20), (.rest, 160), (.driving, 120)])
        spans.append(.init(activity: .ferry, start: start.addingTimeInterval(4 * h), end: start.addingTimeInterval(13 * h)))
        let r = run(spans)
        #expect(r.shifts.first?.restAfter?.kind == .dailyRegular)
        #expect(!has(r, "Art. 9.1–9.2"))
        #expect(!has(r, "Art. 8.1"))
    }

    /// Without ferry time the same day has no daily rest
    @Test func sameRestWithoutFerryIsNotARest() {
        let start = monday.addingTimeInterval(6 * h)
        let r = run(day(start, [(.driving, 240), (.rest, 300), (.work, 20), (.rest, 200), (.driving, 20), (.rest, 160), (.driving, 120)]))
        #expect(r.shifts.first?.restAfter == nil || r.shifts.first?.restAfter?.kind != .dailyRegular)
    }

    /// More than 1 h of interruptions: 11d does not apply
    @Test func ferryInterruptionsOverOneHourDoNotCount() {
        let start = monday.addingTimeInterval(6 * h)
        var spans = day(start, [(.driving, 240), (.rest, 300), (.work, 70), (.rest, 400), (.driving, 120)])
        spans.append(.init(activity: .ferry, start: start.addingTimeInterval(4 * h), end: start.addingTimeInterval(13 * h)))
        let r = run(spans)
        #expect(r.shifts.first?.restAfter?.kind != .dailyRegular)
    }
}
