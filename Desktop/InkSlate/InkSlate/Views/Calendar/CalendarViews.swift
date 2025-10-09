//
//  CalendarViews.swift
//  InkSlate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import EventKit

// MARK: - Main Calendar View
struct CalendarMainView: View {
    @StateObject private var calendarManager = CalendarManager()
    @State private var showingMonthPicker = false
    @State private var showingCalendarSettings = false
    @State private var showingEventEditor = false
    @State private var selectedEvent: EKEvent?
    @State private var selectedTimeSlot: Date?
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header right below navigation bar
            HStack {
                Text("Calendar")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { showingCalendarSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.md)
            
            // Header with date and navigation
            CalendarHeaderView(
                selectedDate: $calendarManager.selectedDate,
                onPreviousWeek: calendarManager.goToPreviousWeek,
                onNextWeek: calendarManager.goToNextWeek,
                onToday: calendarManager.goToToday,
                onMonthTap: { showingMonthPicker = true }
            )
            
            // Calendar content
            if calendarManager.authorizationStatus == .fullAccess {
                CalendarContentView(
                    calendarManager: calendarManager,
                    onEventTap: { event in
                        selectedEvent = event
                        showingEventEditor = true
                    },
                    onTimeSlotTap: { timeSlot in
                        selectedTimeSlot = timeSlot
                        showingEventEditor = true
                    },
                    onEventDelete: { event in
                        calendarManager.deleteEvent(event)
                    }
                )
            } else {
                CalendarPermissionView(
                    authorizationStatus: calendarManager.authorizationStatus,
                    onRequestAccess: calendarManager.requestCalendarAccess
                )
            }
        }
        .sheet(isPresented: $showingMonthPicker) {
            MonthPickerView(selectedDate: $calendarManager.selectedDate)
        }
        .sheet(isPresented: $showingCalendarSettings) {
            CalendarSettingsView(calendarManager: calendarManager)
        }
        .sheet(isPresented: $showingEventEditor) {
            EventEditorView(
                event: selectedEvent,
                startTime: selectedTimeSlot,
                calendarManager: calendarManager
            )
            .onDisappear {
                // Reload events when editor closes
                calendarManager.loadEvents()
            }
        }
    }
}

// MARK: - Calendar Header View
struct CalendarHeaderView: View {
    @Binding var selectedDate: Date
    let onPreviousWeek: () -> Void
    let onNextWeek: () -> Void
    let onToday: () -> Void
    let onMonthTap: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }
    
    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }
    
    private var weekDays: [String] {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    }
    
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let today = selectedDate
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = weekday == 1 ? -6 : 2 - weekday // Adjust for Monday start
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: mondayOffset + dayOffset, to: today)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month and navigation
            HStack {
                Button(action: onPreviousWeek) {
                    Image(systemName: "chevron.left")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                Spacer()
                
                Button(action: onMonthTap) {
                    Text(monthFormatter.string(from: selectedDate))
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.light)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                Button(action: onNextWeek) {
                    Image(systemName: "chevron.right")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 0)
            
                // Week view with days
                VStack(spacing: 0) {
                    // Day labels
                    HStack(spacing: 0) {
                        ForEach(weekDays, id: \.self) { day in
                            Text(day)
                                .font(DesignSystem.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 4)
                
                // Date numbers
                HStack(spacing: 0) {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let isToday = Calendar.current.isDateInToday(date)
                        
                        Button(action: {
                            selectedDate = date
                        }) {
                            VStack(spacing: 1) {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? DesignSystem.Colors.textInverse : (isToday ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary))
                                
                                if isToday {
                                    Circle()
                                        .fill(isSelected ? DesignSystem.Colors.textInverse : DesignSystem.Colors.accent)
                                        .frame(width: 4, height: 4)
                                } else {
                                    Spacer()
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                Circle()
                                    .fill(isSelected ? DesignSystem.Colors.accent : Color.clear)
                                    .frame(width: 32, height: 32)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal)
            
            // Selected date display and Today button
            HStack {
                Text(dateFormatter.string(from: selectedDate))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Today") {
                    onToday()
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .padding(.vertical, 0)
        .background(DesignSystem.Colors.background)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(DesignSystem.Colors.border),
            alignment: .bottom
        )
    }
}

// MARK: - Calendar Content View (FIXED)
struct CalendarContentView: View {
    @ObservedObject var calendarManager: CalendarManager
    let onEventTap: (EKEvent) -> Void
    let onTimeSlotTap: (Date) -> Void
    let onEventDelete: (EKEvent) -> Void
    
    private var allDayEvents: [EKEvent] {
        calendarManager.events.filter { $0.isAllDay }
    }
    
    private var timedEvents: [EKEvent] {
        calendarManager.events.filter { !$0.isAllDay }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // All-day events section at the top
                if !allDayEvents.isEmpty {
                    VStack(spacing: 4) {
                        HStack {
                            Text("All Day")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .trailing)
                            
                            VStack(spacing: 4) {
                                ForEach(allDayEvents, id: \.eventIdentifier) { event in
                                    AllDayEventCard(event: event, onTap: onEventTap, onDelete: onEventDelete)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        Divider()
                            .padding(.horizontal)
                    }
                }
                
                // 24-hour schedule with overlaid events
                ZStack(alignment: .topLeading) {
                    // Background time slots (clickable)
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            TimeSlotBackground(
                                hour: hour,
                                date: calendarManager.selectedDate,
                                onTimeSlotTap: onTimeSlotTap
                            )
                        }
                    }
                    
                    // Overlay all events on top
                    ForEach(timedEvents, id: \.eventIdentifier) { event in
                        PositionedEventView(
                            event: event,
                            date: calendarManager.selectedDate,
                            onTap: onEventTap,
                            onDelete: onEventDelete,
                            calendarManager: calendarManager
                        )
                    }
                }
            }
        }
    }
}

// MARK: - All Day Event Card (Horizontal Layout)
struct AllDayEventCard: View {
    let event: EKEvent
    let onTap: (EKEvent) -> Void
    let onDelete: (EKEvent) -> Void
    
    private var eventViewModel: CalendarEventViewModel {
        CalendarEventViewModel(event: event)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Calendar color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(eventViewModel.color)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(eventViewModel.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let location = eventViewModel.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text("All Day")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(eventViewModel.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(eventViewModel.color.opacity(0.2), lineWidth: 0.5)
                )
        )
        .onTapGesture {
            onTap(event)
        }
    }
}

// MARK: - Time Slot Background (Clickable)
struct TimeSlotBackground: View {
    let hour: Int
    let date: Date
    let onTimeSlotTap: (Date) -> Void
    
    private let hourHeight: CGFloat = 45
    
    private var timeSlot: TimeSlot {
        TimeSlot(hour: hour, date: date)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time label
            VStack {
                        Text(timeSlot.displayTime)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
                
                if timeSlot.isCurrentHour {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                } else {
                    Spacer()
                        .frame(width: 6, height: 6)
                }
            }
            
            // Clickable background
            Button(action: {
                onTimeSlotTap(timeSlot.timeDate)
            }) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: hourHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
            .padding(.horizontal)
            .padding(.vertical, 2)
            .frame(height: hourHeight)
    }
}

// MARK: - Positioned Event View
struct PositionedEventView: View {
    let event: EKEvent
    let date: Date
    let onTap: (EKEvent) -> Void
    let onDelete: (EKEvent) -> Void
    @ObservedObject var calendarManager: CalendarManager
    
    private let hourHeight: CGFloat = 45
    private let timeColumnWidth: CGFloat = 72 // 60 (time width) + 12 (spacing)
    private let horizontalPadding: CGFloat = 16
    
    // Calculate which hour this event starts in
    private var startHour: Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: event.startDate)
    }
    
    // Calculate the minute offset within the start hour
    private var startMinute: Int {
        let calendar = Calendar.current
        return calendar.component(.minute, from: event.startDate)
    }
    
    // Calculate event duration in hours
    private var durationHours: Double {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        return duration / 3600.0 // Convert seconds to hours
    }
    
    // Calculate vertical offset from top of the day
    private var verticalOffset: CGFloat {
        let hourOffset = CGFloat(startHour) * hourHeight
        let minuteOffset = (CGFloat(startMinute) / 60.0) * hourHeight
        return hourOffset + minuteOffset
    }
    
    // Calculate event height
    private var eventHeight: CGFloat {
        max(CGFloat(durationHours) * hourHeight, 30) // Minimum height of 30
    }
    
    var body: some View {
        EventCard(event: event, onTap: onTap, onDelete: onDelete)
            .frame(height: eventHeight)
            .offset(x: timeColumnWidth + horizontalPadding, y: verticalOffset)
            .padding(.trailing, horizontalPadding * 2)
    }
}

// MARK: - Event Time View
struct EventTimeView: View {
    let startTime: Date
    let endTime: Date
    
    private var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }
    
    var body: some View {
        Text("\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
    }
}

// MARK: - Updated Event Card (Compact for multi-hour events)
struct EventCard: View {
    let event: EKEvent
    let onTap: (EKEvent) -> Void
    let onDelete: (EKEvent) -> Void
    
    private var eventViewModel: CalendarEventViewModel {
        CalendarEventViewModel(event: event)
    }
    
    // Adjust layout based on event height
    private var isCompact: Bool {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        return duration / 3600.0 < 0.75 // Less than 45 minutes
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Calendar color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(eventViewModel.color)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(eventViewModel.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(isCompact ? 1 : 3)
                
                if !isCompact {
                    if let location = eventViewModel.location, !location.isEmpty {
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                EventTimeView(
                    startTime: eventViewModel.startTime,
                    endTime: eventViewModel.endTime
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(eventViewModel.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(eventViewModel.color.opacity(0.2), lineWidth: 0.5)
                )
        )
        .onTapGesture {
            onTap(event)
        }
    }
}

// MARK: - All Day Event Banner
struct AllDayEventBanner: View {
    let event: EKEvent
    let onTap: (EKEvent) -> Void
    let onDelete: (EKEvent) -> Void
    
    @State private var showingDeleteAlert = false
    
    private var eventViewModel: CalendarEventViewModel {
        CalendarEventViewModel(event: event)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Vertical banner with event info
            VStack(alignment: .center, spacing: 4) {
                // Event title (rotated for vertical display if needed, or abbreviated)
                Text(String(eventViewModel.title.prefix(3)))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                
                // Delete button
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .frame(height: 24 * 48) // Full height for 24 hours (48px per hour)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(eventViewModel.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(eventViewModel.color.opacity(0.3), lineWidth: 0.5)
        )
        .onTapGesture {
            onTap(event)
        }
        .alert("Delete Event", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete(event)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(eventViewModel.title)'?")
        }
    }
}

// MARK: - Calendar Event View Model
struct CalendarEventViewModel {
    let event: EKEvent
    
    var title: String {
        event.title ?? "Untitled Event"
    }
    
    var location: String? {
        event.location?.isEmpty == false ? event.location : nil
    }
    
    var color: Color {
        if let cgColor = event.calendar.cgColor {
            return Color(cgColor)
        }
        return .blue // Default color
    }
    
    var startTime: Date {
        event.startDate
    }
    
    var endTime: Date {
        event.endDate
    }
    
    var isAllDay: Bool {
        event.isAllDay
    }
}

// MARK: - Calendar Permission View
struct CalendarPermissionView: View {
    let authorizationStatus: EKAuthorizationStatus
    let onRequestAccess: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Calendar Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("To use the calendar features, please allow access to your calendar events.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if authorizationStatus == .notDetermined {
                Button("Allow Calendar Access") {
                    onRequestAccess()
                }
                .buttonStyle(.borderedProminent)
            } else if authorizationStatus == .denied {
                Text("Please enable calendar access in Settings > Privacy & Security > Calendars")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Month Picker View
struct MonthPickerView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    private var weekDays: [String] {
        ["S", "M", "T", "W", "T", "F", "S"]
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(months, id: \.self) { month in
                        VStack(spacing: 12) {
                            // Month header
                            Button(action: {
                                selectedDate = month
                                dismiss()
                            }) {
                                HStack {
                                    Text(dateFormatter.string(from: month))
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    if calendar.isDate(month, equalTo: Date(), toGranularity: .month) {
                                        Text("Current")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Calendar grid
                            VStack(spacing: 8) {
                                // Day headers
                                HStack(spacing: 0) {
                                    ForEach(weekDays, id: \.self) { day in
                                        Text(day)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                
                                // Days grid
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                                    ForEach(daysInMonth(month), id: \.self) { date in
                                        if let date = date {
                                            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                            let isToday = calendar.isDateInToday(date)
                                            let dayNumber = calendar.component(.day, from: date)
                                            
                                            Button(action: {
                                                selectedDate = date
                                                dismiss()
                                            }) {
                                                Text("\(dayNumber)")
                                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                                    .foregroundColor(isSelected ? .white : (isToday ? .accentColor : .primary))
                                                    .frame(width: 32, height: 32)
                                                    .background(
                                                        Circle()
                                                            .fill(isSelected ? Color.accentColor : (isToday ? Color.accentColor.opacity(0.1) : Color.clear))
                                                    )
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        } else {
                                            Spacer()
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var months: [Date] {
        let currentDate = Date()
        var months: [Date] = []
        
        // Show all 12 months of the current year
        let currentYear = calendar.component(.year, from: currentDate)
        
        for month in 1...12 {
            if let monthDate = calendar.date(from: DateComponents(year: currentYear, month: month, day: 1)) {
                months.append(monthDate)
            }
        }
        
        return months
    }
    
    private func daysInMonth(_ month: Date) -> [Date?] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        var days: [Date?] = []
        
        // Add empty spaces for days before the first day of the month
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add all days of the month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        // Fill remaining spaces to complete the grid
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
}

// MARK: - Calendar Settings View
struct CalendarSettingsView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Available Calendars") {
                    ForEach(calendarManager.allCalendars, id: \.calendarIdentifier) { calendar in
                        CalendarToggleRow(
                            calendar: calendar,
                            isSelected: calendarManager.isCalendarSelected(calendar),
                            onToggle: {
                                calendarManager.toggleCalendar(calendar)
                            }
                        )
                    }
                }
            }
            .navigationTitle("Calendar Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Calendar Toggle Row
struct CalendarToggleRow: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            // Calendar color indicator
            Circle()
                .fill(Color(calendar.cgColor))
                .frame(width: 12, height: 12)
            
            // Calendar name
            Text(calendar.title)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: .constant(isSelected))
                .onChange(of: isSelected) {
                    onToggle()
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Event Editor View
struct EventEditorView: View {
    let event: EKEvent?
    let startTime: Date?
    let calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var isAllDay: Bool = false
    @State private var selectedCalendar: EKCalendar?
    
    private var defaultCalendar: EKCalendar? {
        calendarManager.selectedCalendars.first ?? calendarManager.allCalendars.first
    }
    
    var isEditing: Bool {
        event != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Event Details Section
                    VStack(spacing: 16) {
                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event Title")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter event title", text: $title)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        // Location
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Add location (optional)", text: $location)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Add notes (optional)", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .lineLimit(3...6)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    
                    // Time & Date Section
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Time & Date")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Toggle("All Day", isOn: $isAllDay)
                                    .toggleStyle(SwitchToggleStyle())
                            }
                            
                            if !isAllDay {
                                VStack(spacing: 12) {
                                    DatePicker("Starts", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                    
                                    DatePicker("Ends", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                }
                            } else {
                                DatePicker("Date", selection: $startDate, displayedComponents: [.date])
                                    .datePickerStyle(.compact)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    
                    // Calendar Selection
                    if !calendarManager.allCalendars.isEmpty {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Calendar")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Picker("Calendar", selection: $selectedCalendar) {
                                    ForEach(calendarManager.allCalendars, id: \.calendarIdentifier) { calendar in
                                        HStack {
                                            Circle()
                                                .fill(Color(calendar.cgColor))
                                                .frame(width: 16, height: 16)
                                            Text(calendar.title)
                                                .foregroundColor(.primary)
                                        }
                                        .tag(calendar as EKCalendar?)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if isEditing {
                            Button(action: {
                                deleteEvent()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Button("Save") {
                            saveEvent()
                        }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func setupInitialValues() {
        if let event = event {
            // Editing existing event
            title = event.title ?? ""
            location = event.location ?? ""
            notes = event.notes ?? ""
            startDate = event.startDate
            endDate = event.endDate
            isAllDay = event.isAllDay
            selectedCalendar = event.calendar
        } else if let startTime = startTime {
            // Creating new event
            title = ""
            location = ""
            notes = ""
            startDate = startTime
            endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
            isAllDay = false
            selectedCalendar = defaultCalendar
        }
    }
    
    private func saveEvent() {
        let eventToSave: EKEvent
        let calendar = Calendar.current
        
        if let existingEvent = event {
            // Update existing event
            eventToSave = existingEvent
        } else {
            // Create new event
            eventToSave = EKEvent(eventStore: calendarManager.store)
            
            // CRITICAL FIX: Use proper calendar
            if let selected = selectedCalendar, selected.allowsContentModifications {
                eventToSave.calendar = selected
            } else if let defaultCal = calendarManager.store.defaultCalendarForNewEvents {
                eventToSave.calendar = defaultCal
            } else {
                // Fallback to first writable calendar
                if let writableCal = calendarManager.allCalendars.first(where: { $0.allowsContentModifications }) {
                    eventToSave.calendar = writableCal
                } else {
                    // Show error - no writable calendars available
                    print("ERROR: No writable calendars available")
                    calendarManager.debugEventSaving()
                    return
                }
            }
        }
        
        eventToSave.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        eventToSave.location = location.isEmpty ? nil : location
        eventToSave.notes = notes.isEmpty ? nil : notes
        eventToSave.isAllDay = isAllDay
        
        if isAllDay {
            // For all-day events, set times to midnight
            eventToSave.startDate = calendar.startOfDay(for: startDate)
            eventToSave.endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startDate))!
        } else {
            eventToSave.startDate = startDate
            eventToSave.endDate = endDate
            
            // Validate end date is after start date
            if endDate <= startDate {
                eventToSave.endDate = calendar.date(byAdding: .hour, value: 1, to: startDate)!
            }
        }
        
        do {
            try calendarManager.store.save(eventToSave, span: EKSpan.thisEvent, commit: true)
            calendarManager.loadEvents()
            dismiss()
        } catch {
            print("Error saving event: \(error.localizedDescription)")
            calendarManager.debugEventSaving()
        }
    }
    
    private func deleteEvent() {
        guard let eventToDelete = event else { return }
        calendarManager.deleteEvent(eventToDelete)
        dismiss()
    }
}

