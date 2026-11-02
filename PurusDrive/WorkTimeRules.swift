import Foundation

/// ARV 1 checks (SR 822.221, version of 1 May 2025) for the personal work-time log.
/// Not covered: two drivers (Art. 9.6, 11c), ferry/train (11d), round trips (11a), abroad-only rules (11.7).
enum WorkTimeRules {

    struct Span: Equatable {
        var activity: WorkActivity
        var start: Date
        var end: Date
        var exception = false
    }

    struct Finding: Identifiable, Equatable {
        var id: String { "\(date.timeIntervalSince1970)-\(text)" }
        let date: Date
        /// false = warning (orange), true = breach (red)
        let severe: Bool
        let text: String
        let article: String
    }

    enum RestKind: String {
        case dailyRegular = "daily rest"
        case dailySplit = "daily rest (split)"
        case dailyReduced = "reduced daily rest"
        case weeklyRegular = "weekly rest"
        case weeklyReduced = "reduced weekly rest"
        case tooShort = "rest too short"
    }

    struct Rest: Equatable {
        let start: Date
        let end: Date
        let ongoing: Bool
        var kind: RestKind?
        var hours: Double { end.timeIntervalSince(start) / 3600 }
    }

    /// From the end of one daily/weekly rest to the start of the next.
    struct Shift: Identifiable, Equatable {
        var id: Date { start }
        let start: Date
        let end: Date
        var driving: TimeInterval = 0
        /// driving + other work + breaks under 15 min (Art. 2f)
        var work: TimeInterval = 0
        var standby: TimeInterval = 0
        /// breaks of 15 min or more
        var breaks: TimeInterval = 0
        /// first part (3 h or more) of a split daily rest
        var splitPart: TimeInterval?
        var restAfter: Rest?
        var exception = false
    }

    struct Week: Identifiable, Equatable {
        var id: Date { start }
        let start: Date
        var driving: TimeInterval = 0
        var work: TimeInterval = 0
        var standby: TimeInterval = 0
        /// average weekly work over the last 26 weeks (Art. 6)
        var average26: TimeInterval = 0
    }

    /// Rest still to make up (reduced weekly rest, Art. 11.2; extended driving, Art. 12).
    struct Owed: Equatable {
        let hours: Double
        let due: Date
        let reason: String
    }

    struct Status: Equatable {
        var drivingSinceBreak: TimeInterval = 0
        var shiftDriving: TimeInterval = 0
        /// latest start of the daily rest (11 h fits in the 24 h)
        var dailyRestBy: Date?
        var weeklyRestBy: Date?
        var openOwed: [Owed] = []
    }

    struct Report: Equatable {
        var shifts: [Shift] = []
        var weeks: [Week] = []
        var findings: [Finding] = []
        var status = Status()
    }

    static let h: TimeInterval = 3600
    static let m: TimeInterval = 60

    static func evaluate(_ input: [Span], now: Date, calendar cal: Calendar = .current) -> Report {
        var report = Report()

        // 1) active spans only, sorted, no overlaps; everything between them is free time
        var active: [Span] = []
        for s in input.filter({ $0.activity.isActive }).sorted(by: { $0.start < $1.start }) {
            var s = s
            s.end = min(s.end, now)
            if let last = active.last, s.start < last.end { s.start = last.end }
            if s.end > s.start { active.append(s) }
        }
        guard !active.isEmpty else { return report }

        enum Item { case on(Span), off(Rest) }
        var items: [Item] = []
        for (i, s) in active.enumerated() {
            if i > 0, s.start > active[i - 1].end { items.append(.off(Rest(start: active[i - 1].end, end: s.start, ongoing: false))) }
            items.append(.on(s))
        }
        if let last = active.last, last.end < now { items.append(.off(Rest(start: last.end, end: now, ongoing: true))) }

        // 2) shifts, split at rests of 9 h or more
        var shiftItems: [[Item]] = [[]]
        var shiftRests: [Rest?] = []
        for item in items {
            if case .off(let r) = item, r.end.timeIntervalSince(r.start) >= 9 * h {
                shiftRests.append(r)
                shiftItems.append([])
            } else {
                shiftItems[shiftItems.count - 1].append(item)
            }
        }
        shiftRests.append(nil)

        var owed: [(Owed, after: Date)] = []
        var reducedDaily = 0
        var extendedDays: [Date: Int] = [:]
        var lastWeekly: Rest?
        var shortBreaks: [Date: TimeInterval] = [:]

        func add(_ date: Date, _ severe: Bool, _ text: String, _ art: String) {
            report.findings.append(Finding(date: date, severe: severe, text: text, article: art))
        }

        for (idx, list) in shiftItems.enumerated() {
            guard let firstOn = list.first(where: { if case .on = $0 { return true }; return false }),
                  case .on(let first) = firstOn else { continue }
            let lastEnd: Date = list.reversed().compactMap { if case .on(let s) = $0 { return s.end }; return nil }.first ?? first.end
            var shift = Shift(start: first.start, end: lastEnd)
            var sinceBreak: TimeInterval = 0, had15 = false, drivingFlagged = false
            var continuous: TimeInterval = 0, workFlagged = false

            for item in list {
                switch item {
                case .on(let s):
                    let d = s.end.timeIntervalSince(s.start)
                    if s.exception { shift.exception = true }
                    switch s.activity {
                    case .driving:
                        shift.driving += d; shift.work += d; continuous += d
                        if sinceBreak + d > 4.5 * h && !drivingFlagged {
                            drivingFlagged = true
                            add(s.start.addingTimeInterval(4.5 * h - sinceBreak), true, "More than 4 h 30 min of driving without a 45-min break", "Art. 8.1")
                        }
                        sinceBreak += d
                    case .work:
                        shift.work += d; continuous += d
                    case .standby:
                        shift.standby += d
                    default: break
                    }
                    if continuous > 6 * h && !workFlagged {
                        workFlagged = true
                        add(s.end, true, "More than 6 h of work without a break", "Art. 8.3")
                    }
                case .off(let r):
                    let d = r.end.timeIntervalSince(r.start)
                    if d < 15 * m {
                        shift.work += d; continuous += d   // Art. 2f: short breaks are work time
                        shortBreaks[startOfWeek(r.start, cal), default: 0] += d
                    } else {
                        shift.breaks += d
                        continuous = 0; workFlagged = false
                        if d >= 45 * m || (had15 && d >= 30 * m) { sinceBreak = 0; had15 = false; drivingFlagged = false } else { had15 = true }
                        if d >= 3 * h { shift.splitPart = d }
                    }
                }
            }

            // rest that closes this shift
            if var rest = shiftRests[idx] {
                let window = shift.start.addingTimeInterval(24 * h)
                let inWindow = max(0, min(rest.end, window).timeIntervalSince(rest.start))
                let decided = !rest.ongoing || inWindow >= 11 * h || rest.end >= window
                if decided {
                    if inWindow >= 11 * h { rest.kind = .dailyRegular }
                    else if inWindow >= 9 * h, shift.splitPart != nil { rest.kind = .dailySplit }
                    else if inWindow >= 9 * h {
                        rest.kind = .dailyReduced
                        reducedDaily += 1
                        if reducedDaily > 3 { add(rest.start, true, "More than three reduced daily rests between two weekly rests", "Art. 9.3") }
                    } else {
                        rest.kind = .tooShort
                        add(rest.start, true, String(format: "Daily rest too short or too late: %.1f h within 24 h of the start (11 h needed, 9 h reduced)", inWindow / h), "Art. 9.1–9.2")
                    }
                }
                if rest.hours >= 24 {
                    rest.kind = rest.hours >= 45 ? .weeklyRegular : (rest.ongoing ? rest.kind : .weeklyReduced)
                    if !rest.ongoing || rest.hours >= 45 {
                        if let prev = lastWeekly {
                            let gap = rest.start.timeIntervalSince(prev.end)
                            if gap > 144 * h { add(rest.start, true, String(format: "Weekly rest started %.0f h after the last one (6 × 24 h allowed)", gap / h), "Art. 11.3") }
                            if prev.hours < 45 && rest.hours < 45 { add(rest.start, true, "Two reduced weekly rests in a row", "Art. 11.2") }
                        }
                        if rest.hours < 45 && !rest.ongoing {
                            owed.append((Owed(hours: 45 - rest.hours, due: endOfWeek(rest.start, plus: 3, cal), reason: "Reduced weekly rest"), after: rest.end))
                        }
                        lastWeekly = rest
                        reducedDaily = 0
                    }
                }
                shift.restAfter = rest
            }

            // driving per shift (Art. 5.1, Art. 12)
            let week = startOfWeek(shift.start, cal)
            if shift.driving > 9 * h {
                extendedDays[week, default: 0] += 1
                let limit = 10 * h + (shift.exception ? 2 * h : 0)
                if shift.driving > limit {
                    add(shift.start, true, "Driving \(dur(shift.driving)) in one day (max 9 h, twice a week 10 h)", "Art. 5.1")
                } else if shift.driving > 10 * h {
                    owed.append((Owed(hours: (shift.driving - 10 * h) / h, due: endOfWeek(shift.start, plus: 3, cal), reason: "Extended driving (exception)"), after: shift.end))
                }
                if extendedDays[week]! > 2 { add(shift.start, true, "More than two days with over 9 h driving in one week", "Art. 5.1") }
            }

            // breaks per day (Art. 8.3): only once the day is closed
            if shift.restAfter != nil {
                if shift.work > 9 * h && shift.breaks < 45 * m { add(shift.start, true, "Over 9 h of work needs 45 min of breaks (\(dur(shift.breaks)) taken)", "Art. 8.3") }
                else if shift.work > 6 * h && shift.breaks < 30 * m { add(shift.start, true, "6–9 h of work needs 30 min of breaks (\(dur(shift.breaks)) taken)", "Art. 8.3") }
            }

            // live numbers only while the day is not closed by a rest
            if shift.restAfter == nil {
                report.status.drivingSinceBreak = sinceBreak
                report.status.shiftDriving = shift.driving
                report.status.dailyRestBy = shift.start.addingTimeInterval(13 * h)
            }
            report.shifts.append(shift)
        }

        // rest made up: a later rest of 9 h+ with enough extra time in one piece
        let rests = report.shifts.compactMap(\.restAfter).filter { !$0.ongoing }
        var surplus = rests.map { r -> (Rest, TimeInterval) in
            let base: TimeInterval = r.hours >= 45 ? 45 * h : (r.hours >= 24 ? .infinity : 11 * h)
            return (r, base == .infinity ? 0 : max(0, r.end.timeIntervalSince(r.start) - base))
        }
        for (o, after) in owed {
            if let i = surplus.firstIndex(where: { $0.0.start >= after && $0.0.start <= o.due && $0.1 >= o.hours * h }) {
                surplus[i].1 -= o.hours * h
            } else if o.due < now {
                add(o.due, true, String(format: "%@: %.1f h of rest not made up in time", o.reason, o.hours), o.reason.hasPrefix("Reduced") ? "Art. 11.2" : "Art. 12")
            } else {
                report.status.openOwed.append(o)
            }
        }
        if let lw = lastWeekly { report.status.weeklyRestBy = lw.ongoing ? nil : lw.end.addingTimeInterval(144 * h) }

        // weeks (Monday 00:00 to Sunday 24:00, Art. 2j)
        var weeks: [Date: Week] = [:]
        for s in active {
            var cursor = s.start
            while cursor < s.end {
                let ws = startOfWeek(cursor, cal)
                let we = cal.date(byAdding: .day, value: 7, to: ws)!
                let piece = min(s.end, we).timeIntervalSince(cursor)
                var w = weeks[ws] ?? Week(start: ws)
                switch s.activity {
                case .driving: w.driving += piece; w.work += piece
                case .work: w.work += piece
                case .standby: w.standby += piece
                default: break
                }
                weeks[ws] = w
                cursor = min(s.end, we)
            }
        }
        for (wk, t) in shortBreaks { weeks[wk, default: Week(start: wk)].work += t }
        let first = weeks.keys.min()!, lastWeek = startOfWeek(now, cal)
        var all: [Week] = []
        var ws = first
        while ws <= lastWeek {
            all.append(weeks[ws] ?? Week(start: ws))
            ws = cal.date(byAdding: .day, value: 7, to: ws)!
        }
        for i in all.indices {
            let window = all[max(0, i - 25)...i]
            all[i].average26 = window.map(\.work).reduce(0, +) / Double(window.count)
            let w = all[i]
            if w.driving > 56 * h { add(w.start, true, "Driving \(dur(w.driving)) in one week (max 56 h)", "Art. 5.2") }
            if i > 0, w.driving + all[i - 1].driving > 90 * h { add(w.start, true, "Driving \(dur(w.driving + all[i - 1].driving)) in two weeks (max 90 h)", "Art. 5.3") }
            if w.work > 60 * h { add(w.start, true, "Work \(dur(w.work)) in one week (max 60 h)", "Art. 6.1") }
            if all.count >= 2, w.average26 > 48 * h { add(w.start, false, "26-week average work \(dur(w.average26)) (max 48 h)", "Art. 6.1") }
        }
        report.weeks = all
        report.findings.sort { $0.date > $1.date }
        return report
    }

    static func startOfWeek(_ d: Date, _ cal: Calendar) -> Date {
        var c = cal
        c.firstWeekday = 2
        return c.dateInterval(of: .weekOfYear, for: d)!.start
    }

    /// end of the week of `d`, plus `plus` weeks
    static func endOfWeek(_ d: Date, plus: Int, _ cal: Calendar) -> Date {
        cal.date(byAdding: .day, value: 7 * (plus + 1), to: startOfWeek(d, cal))!
    }

    static func dur(_ t: TimeInterval) -> String {
        let mins = Int((t / 60).rounded())
        return String(format: "%d h %02d", mins / 60, mins % 60)
    }
}
