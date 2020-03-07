//
//  AllDayEvent.swift
//  JZCalendarViewExample
//
//  Created by Jeff Zhang on 3/4/18.
//  Copyright © 2018 Jeff Zhang. All rights reserved.
//

import JZCalendarWeekView

class CalendarEvent: JZBaseEvent {
	let task: Models.Task
	init() {
        // If you want to have you custom uid, you can set the parent class's id with your uid or UUID().uuidString (In this case, we just use the base class id)
		super.init(id: String(task.id), startDate: task.fromDate, endDate: task.toDate, descriptor: EventDescription.init(isAllDay: self.task.isAllDay, text: self.task.title, attributedText: nil, font: .eventTitle, color: .clear, textColor: .white, backgroundColor: task.category?.color.hexColor.color ?? UIColor.styled(.grayMedium)!))
    }

    override func copy(with zone: NSZone?) -> Any {
		return CalendarEvent(task: self.task)
    }
}
