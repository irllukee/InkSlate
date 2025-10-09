//
//  CalendarModels.swift
//  InkSlate
//
//  Created by Lucas Waldron on 10/9/25.
//

import Foundation
import EventKit
import SwiftUI

// MARK: - Calendar Manager
class CalendarManager: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var events: [EKEvent] = []
    @Published var allCalendars: [EKCalendar] = []
    @Published var selectedCalendars: [EKCalendar] = []
    
    let store = EKEventStore()
    
    init() {
        checkAuthorizationStatus()
        loadCalendars()
        
        // Load selected calendars from UserDefaults
        loadSelectedCalendars()
        
        // Load events if authorized
        if authorizationStatus == .fullAccess {
            loadEvents()
        }
    }
    
    // MARK: - Authorization
    private func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    func requestCalendarAccess() {
        store.requestFullAccessToEvents { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.checkAuthorizationStatus()
                if granted {
                    self?.loadCalendars()
                    self?.loadEvents()
                }
            }
        }
    }
    
    // MARK: - Calendar Management
    private func loadCalendars() {
        allCalendars = store.calendars(for: .event)
        
        // If no calendars selected, select all by default
        if selectedCalendars.isEmpty {
            selectedCalendars = allCalendars
            saveSelectedCalendars()
        }
    }
    
    func isCalendarSelected(_ calendar: EKCalendar) -> Bool {
        return selectedCalendars.contains(where: { $0.calendarIdentifier == calendar.calendarIdentifier })
    }
    
    func toggleCalendar(_ calendar: EKCalendar) {
        if let index = selectedCalendars.firstIndex(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
            selectedCalendars.remove(at: index)
        } else {
            selectedCalendars.append(calendar)
        }
        saveSelectedCalendars()
        loadEvents()
    }
    
    private func saveSelectedCalendars() {
        let identifiers = selectedCalendars.map { $0.calendarIdentifier }
        UserDefaults.standard.set(identifiers, forKey: "SelectedCalendarIdentifiers")
    }
    
    private func loadSelectedCalendars() {
        guard let identifiers = UserDefaults.standard.array(forKey: "SelectedCalendarIdentifiers") as? [String] else {
            return
        }
        
        selectedCalendars = allCalendars.filter { calendar in
            identifiers.contains(calendar.calendarIdentifier)
        }
    }
    
    // MARK: - Event Management
    func loadEvents() {
        guard authorizationStatus == .fullAccess else { return }
        
        // Get start and end of the selected week
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? selectedDate
        
        // Create predicate for selected calendars
        let predicate = store.predicateForEvents(
            withStart: startOfWeek,
            end: endOfWeek,
            calendars: selectedCalendars.isEmpty ? nil : selectedCalendars
        )
        
        events = store.events(matching: predicate)
    }
    
    func deleteEvent(_ event: EKEvent) {
        do {
            try store.remove(event, span: .thisEvent, commit: true)
            loadEvents()
        } catch {
            print("Error deleting event: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Navigation
    func goToPreviousWeek() {
        selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        loadEvents()
    }
    
    func goToNextWeek() {
        selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        loadEvents()
    }
    
    func goToToday() {
        selectedDate = Date()
        loadEvents()
    }
    
    // MARK: - Event Helpers
    func eventsForHour(_ hour: Int, on date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay),
              let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) else {
            return []
        }
        
        return events.filter { event in
            guard !event.isAllDay else { return false }
            
            let eventStart = event.startDate ?? Date()
            
            // Only return events that START in this hour slot
            // This prevents multi-hour events from appearing in multiple hour blocks
            return eventStart >= hourStart && eventStart < hourEnd
        }
    }
    
    func eventDuration(_ event: EKEvent) -> Double {
        guard let start = event.startDate, let end = event.endDate else { return 1.0 }
        let duration = end.timeIntervalSince(start)
        return duration / 3600.0 // Convert to hours
    }
    
    func eventStartMinute(_ event: EKEvent) -> Int {
        guard let start = event.startDate else { return 0 }
        let calendar = Calendar.current
        return calendar.component(.minute, from: start)
    }
    
    // MARK: - Debug
    func debugEventSaving() {
        print("=== Calendar Debug Info ===")
        print("Authorization Status: \(authorizationStatus.rawValue)")
        print("All Calendars: \(allCalendars.count)")
        for calendar in allCalendars {
            print("  - \(calendar.title) [\(calendar.type.rawValue)] - Allows modifications: \(calendar.allowsContentModifications)")
        }
        print("Default Calendar: \(store.defaultCalendarForNewEvents?.title ?? "None")")
        print("========================")
    }
}

// MARK: - Time Slot Model
struct TimeSlot {
    let hour: Int
    let date: Date
    
    var displayTime: String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else {
            return "\(hour):00"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: hourDate)
    }
    
    var isCurrentHour: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        let currentHour = calendar.component(.hour, from: now)
        let currentDay = calendar.startOfDay(for: now)
        let slotDay = calendar.startOfDay(for: date)
        
        return currentHour == hour && currentDay == slotDay
    }
    
    var timeDate: Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? date
    }
}

// MARK: - Calendar View Type Enum
enum CalendarViewType: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case day = "Day"
    
    var icon: String {
        switch self {
        case .week: return "calendar"
        case .month: return "calendar.badge.clock"
        case .day: return "calendar.day.timeline.left"
        }
    }
}


