//
//  Date+Ext.swift
//  DonorTrack
//
//  Created by Hunter Dobbelmann on 1/16/23.
//

import Foundation

// MARK: Check if two dates are part of same week
// let fiveDaysInSeconds = 432_000.0
// Calendar.current.isDate(Date.now, equalTo: Date.now.advanced(by: fiveDaysInSeconds), toGranularity: .weekOfYear)

extension Date {
    static var durationFormat: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter
    }

    var month: Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.month, .year], from: self))!
    }

	func startOfWeek(using calendar: Calendar = .current) -> Date {
		calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date!
	}
	func startOfWeekFiveWeeksAgo(using calendar: Calendar = .current) -> Date {
		let fiveWeeksAgoInSeconds: TimeInterval = (86_400 * -7) * 5
		let fiveWeeksAgo = Date.now.addingTimeInterval(fiveWeeksAgoInSeconds)
		return fiveWeeksAgo.startOfWeek(using: calendar)
	}
}

extension ClosedRange<Date> {
    func asDurationString() -> String {
        Date.durationFormat.string(from: self.upperBound.timeIntervalSince(self.lowerBound)) ?? "Error"
    }
}
