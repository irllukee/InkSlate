//
//  CalendarViews.swift
//  InkSlate
//

import SwiftUI
import EventKit

// MARK: - Calendar Manager
class CalendarManager: ObservableObject {
    @Published var selectedDate = Date()
    @Published var allCalendars: [EKCalendar] = []
    @Published var selectedCalendars: Set<String> = []
    @Published var events: [EKEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    let store = EKEventStore()
    private var reloadWorkItem: DispatchWorkItem?
    private var reloadTask: Task<Void, Never>?
    private var cachedWindow: (start: Date, end: Date)?

    init() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.storeChanged()
        }
        requestAccess()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func storeChanged() {
        loadCalendars()
        loadEvents(center: selectedDate)
    }

    func requestAccess() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if #available(iOS 17, *) {
                let status = EKEventStore.authorizationStatus(for: .event)
                self.authorizationStatus = status

                switch status {
                case .notDetermined:
                    do {
                        let granted = try await store.requestFullAccessToEvents()
                        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                        if granted {
                            self.loadCalendars()
                            self.loadEvents(center: selectedDate)
                        } else {
                            self.errorMessage = "Calendar access denied."
                        }
                    } catch {
                        self.errorMessage = "Calendar access error: \(error.localizedDescription)"
                    }

                case .fullAccess:
                    self.loadCalendars()
                    self.loadEvents(center: selectedDate)

                case .writeOnly:
                    self.errorMessage = "Read access unavailable. Enable Full Access in Settings > Privacy & Security > Calendars."

                case .denied, .restricted:
                    self.errorMessage = "Calendar access denied."

                default: break
                }
            } else {
                let status = EKEventStore.authorizationStatus(for: .event)
                self.authorizationStatus = status

                switch status {
                case .notDetermined:
                    store.requestAccess(to: .event) { granted, _ in
                        DispatchQueue.main.async {
                            self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                            if granted {
                                self.loadCalendars()
                                self.loadEvents(center: self.selectedDate)
                            } else {
                                self.errorMessage = "Calendar access denied."
                            }
                        }
                    }
                case .authorized:
                    self.loadCalendars()
                    self.loadEvents(center: selectedDate)
                case .denied, .restricted:
                    self.errorMessage = "Calendar access denied."
                default: break
                }
            }
        }
    }

    private func loadCalendars() {
        allCalendars = store.calendars(for: .event)
        if selectedCalendars.isEmpty {
            // Default to all visible calendars on first load
            selectedCalendars = Set(allCalendars.map { $0.calendarIdentifier })
        } else {
            // Drop any that disappeared
            let existing = Set(allCalendars.map { $0.calendarIdentifier })
            selectedCalendars = selectedCalendars.intersection(existing)
        }
    }

    /// Load events centered around a date (default = selectedDate) in a ±3 month window.
    func loadEvents(center: Date? = nil) {
        reloadTask?.cancel()
        reloadTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isLoading = true
            self.errorMessage = nil

            let base = center ?? selectedDate
            let cal = Calendar.current
            let startDate = cal.date(byAdding: .month, value: -3, to: cal.startOfDay(for: base))!
            let endDate   = cal.date(byAdding: .month, value:  3, to: cal.startOfDay(for: base))!

            // Include only selected calendars (or all if none selected)
            let allAvailableCalendars = store.calendars(for: .event)
            let visibleCalendars: [EKCalendar]
            
            if self.selectedCalendars.isEmpty {
                // If no calendars are selected, show all calendars
                visibleCalendars = allAvailableCalendars
            } else {
                // Filter to only selected calendars
                visibleCalendars = allAvailableCalendars.filter { self.selectedCalendars.contains($0.calendarIdentifier) }
            }

            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: visibleCalendars)
            let fetched = store.events(matching: predicate)

            self.events = fetched.sorted { $0.startDate < $1.startDate }
            self.isLoading = false
        }
    }

    func goToPreviousWeek() {
        selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
    }

    func goToNextWeek() {
        selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
    }

    func goToToday() { selectedDate = Date() }

    func isCalendarSelected(_ calendar: EKCalendar) -> Bool {
        selectedCalendars.contains(calendar.calendarIdentifier)
    }

    func setCalendar(_ calendar: EKCalendar, enabled: Bool) {
        if enabled {
            selectedCalendars.insert(calendar.calendarIdentifier)
        } else {
            selectedCalendars.remove(calendar.calendarIdentifier)
        }
        loadEvents(center: selectedDate)
    }

    func deleteEvent(_ event: EKEvent) {
        do {
            try store.remove(event, span: .thisEvent, commit: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.loadEvents(center: self.selectedDate)
            }
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func refreshEvents() { loadEvents(center: selectedDate) }

    func getEvents(for date: Date) -> [EKEvent] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        return events.filter { $0.startDate < dayEnd && $0.endDate > dayStart }
    }

    func getEvents(for timeSlot: TimeSlot) -> [EKEvent] {
        let cal = Calendar.current
        let start = timeSlot.timeDate
        let end = cal.date(byAdding: .hour, value: 1, to: start)!
        return events.filter { $0.startDate < end && $0.endDate > start }
    }

    func debugEventSaving() {
        // Optional: add logging if needed
    }
    
    /// Get upcoming events (current and future events)
    func getUpcomingEvents(limit: Int? = nil) -> [EKEvent] {
        let now = Date()
        // Filter events that haven't ended yet (endDate >= now)
        // This includes events happening now and future events
        let upcoming = events.filter { event in
            event.endDate >= now
        }
        .sorted { $0.startDate < $1.startDate }
        
        if let limit = limit {
            return Array(upcoming.prefix(limit))
        }
        return upcoming
    }
}

// MARK: - Time Slot Helper
struct TimeSlot: Hashable {
    let hour: Int
    let date: Date

    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: timeDate)
    }

    var timeDate: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    var isCurrentHour: Bool {
        let calendar = Calendar.current
        let now = Date()
        guard calendar.isDate(date, inSameDayAs: now) else { return false }
        let currentHour = calendar.component(.hour, from: now)
        return hour == currentHour
    }
}

// MARK: - Event Layout Helper
struct EventLayout: Hashable {
    let event: EKEvent  // FIXED: Store the actual event, not just ID
    let column: Int
    let totalColumns: Int
    let startOffset: CGFloat
    let height: CGFloat
    
    // Keep ID for Hashable conformance
    var eventIdentifier: String { event.eventIdentifier }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(eventIdentifier)
    }
    
    static func == (lhs: EventLayout, rhs: EventLayout) -> Bool {
        lhs.eventIdentifier == rhs.eventIdentifier
    }
}

// MARK: - Main Calendar View
struct CalendarMainView: View {
    @StateObject private var calendarManager = CalendarManager()
    private enum CalendarSheet: Identifiable { case monthPicker, settings, editor; var id: Int { hashValue } }
    @State private var activeSheet: CalendarSheet?
    @State private var selectedEvent: EKEvent?
    @State private var selectedTimeSlot: Date?
    @State private var viewMode: ViewMode = .calendar
    
    enum ViewMode {
        case calendar
        case list
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title/gear/view toggle
            HStack {
                Text("Calendar")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                HStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: { 
                        withAnimation {
                            let newMode: ViewMode = viewMode == .calendar ? .list : .calendar
                            viewMode = newMode
                            // Refresh events when switching to list view to ensure current data
                            if newMode == .list {
                                calendarManager.loadEvents(center: Date())
                            }
                        }
                    }) {
                        Image(systemName: viewMode == .calendar ? "list.bullet" : "calendar")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    Button(action: { activeSheet = .settings }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.md)

            // Header (only show in calendar mode)
            if viewMode == .calendar {
                CalendarHeaderView(
                    selectedDate: $calendarManager.selectedDate,
                    onPreviousWeek: { calendarManager.goToPreviousWeek() },
                    onNextWeek: { calendarManager.goToNextWeek() },
                    onToday: { calendarManager.goToToday() },
                    onMonthTap: { activeSheet = .monthPicker }
                )
            }

            // Content
            if showsReadableAccess(status: calendarManager.authorizationStatus) {
                if viewMode == .calendar {
                    CalendarContentView(
                        calendarManager: calendarManager,
                        onEventTap: { event in
                            selectedEvent = event
                            activeSheet = .editor
                        },
                        onTimeSlotTap: { time in
                            selectedTimeSlot = time
                            activeSheet = .editor
                        },
                        onEventDelete: { event in
                            calendarManager.deleteEvent(event)
                        }
                    )
                    .environmentObject(calendarManager)
                    .onChange(of: calendarManager.selectedDate) { _, newValue in
                        calendarManager.loadEvents(center: newValue)
                    }
                } else {
                    CalendarListView(
                        calendarManager: calendarManager,
                        onEventTap: { event in
                            selectedEvent = event
                            activeSheet = .editor
                        },
                        onEventDelete: { event in
                            calendarManager.deleteEvent(event)
                        }
                    )
                    .environmentObject(calendarManager)
                    .onAppear {
                        // Refresh events when switching to list view - load from today to catch all upcoming events
                        calendarManager.loadEvents(center: Date())
                    }
                    .refreshable {
                        // Pull to refresh
                        calendarManager.loadEvents(center: Date())
                    }
                }
            } else {
                CalendarPermissionView(
                    authorizationStatus: calendarManager.authorizationStatus,
                    onRequestAccess: { calendarManager.requestAccess() }
                )
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .monthPicker:
                MonthPickerView(selectedDate: $calendarManager.selectedDate)
            case .settings:
                CalendarSettingsView(calendarManager: calendarManager)
            case .editor:
                EventEditorView(
                    event: selectedEvent,
                    startTime: selectedTimeSlot,
                    calendarManager: calendarManager
                )
                .onDisappear {
                    selectedEvent = nil
                    selectedTimeSlot = nil
                    // Refresh events after editing (for both calendar and list views)
                    calendarManager.loadEvents(center: calendarManager.selectedDate)
                }
            }
        }
        .onAppear {
            calendarManager.loadEvents(center: calendarManager.selectedDate)
        }
    }

    private func showsReadableAccess(status: EKAuthorizationStatus) -> Bool {
        if #available(iOS 17, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let firstWeekday = calendar.firstWeekday
        let weekday = calendar.component(.weekday, from: selectedDate)
        let offset = firstWeekday - weekday
        let startOfWeek = calendar.date(byAdding: .day, value: offset, to: selectedDate) ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Month + nav
            HStack {
                Button(action: onPreviousWeek) {
                    Image(systemName: "chevron.left")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                Spacer()
                Button(action: onMonthTap) {
                    Text(Self.monthFormatter.string(from: selectedDate))
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

            // Day labels (Mon..Sun)
            HStack(spacing: 0) {
                let cal = Calendar.current
                let symbols = cal.shortWeekdaySymbols
                let start = cal.firstWeekday - 1 // 0-indexed
                let rotated = Array(symbols[start...] + symbols[..<start])
                ForEach(rotated, id: \.self) { day in
                    Text(day)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 4)

            // Dates
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let isToday = Calendar.current.isDateInToday(date)
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 1) {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? DesignSystem.Colors.textInverse :
                                                (isToday ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary))
                            if isToday {
                                Circle()
                                    .fill(isSelected ? DesignSystem.Colors.textInverse : DesignSystem.Colors.accent)
                                    .frame(width: 4, height: 4)
                            } else {
                                Spacer().frame(width: 4, height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Circle()
                                .fill(isSelected ? DesignSystem.Colors.accent : .clear)
                                .frame(width: 32, height: 32)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
            .padding(.horizontal)

            // Selected label + Today
            HStack {
                Text(Self.dateFormatter.string(from: selectedDate))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Spacer()
                Button("Today") { onToday() }
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
            Rectangle().frame(height: 0.5).foregroundColor(DesignSystem.Colors.border),
            alignment: .bottom
        )
    }
}

// MARK: - Calendar Content View
struct CalendarContentView: View {
    @ObservedObject var calendarManager: CalendarManager
    let onEventTap: (EKEvent) -> Void
    let onTimeSlotTap: (Date) -> Void
    let onEventDelete: (EKEvent) -> Void

    private let calendar = Calendar.current

    private var allDayEvents: [EKEvent] {
        calendarManager.events.filter { event in
            guard event.isAllDay else { return false }
            let startDay = calendar.startOfDay(for: event.startDate)
            let endDay   = calendar.startOfDay(for: event.endDate) // end exclusive
            let selectedDay = calendar.startOfDay(for: calendarManager.selectedDate)
            return startDay <= selectedDay && selectedDay < endDay
        }
    }

    private var timedEvents: [EKEvent] {
        let dayStart = calendar.startOfDay(for: calendarManager.selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        return calendarManager.events.filter { e in
            !e.isAllDay && e.startDate < dayEnd && e.endDate > dayStart
        }
    }

    private var eventLayouts: [EventLayout] {
        calculateEventLayouts(for: timedEvents, on: calendarManager.selectedDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
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
                        Divider().padding(.horizontal)
                    }
                }

                // GeometryReader for correct widths on iPad/split view
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    ZStack(alignment: .topLeading) {
                        // 24 rows background
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                TimeSlotBackground(
                                    hour: hour,
                                    date: calendarManager.selectedDate,
                                    onTimeSlotTap: onTimeSlotTap
                                )
                            }
                        }

                        // FIXED: Pass actual events with their layouts
                        ForEach(eventLayouts, id: \.eventIdentifier) { layout in
                            PositionedEventView(
                                layout: layout,
                                containerWidth: totalWidth,
                                date: calendarManager.selectedDate,
                                onTap: onEventTap,
                                onDelete: onEventDelete
                            )
                        }
                    }
                }
                .frame(height: 24 * 45) // 24 hours * hourHeight
                .frame(minHeight: 24 * 45)
            }
        }
    }

    // FIXED: Store actual events in EventLayout instead of just IDs
    private func calculateEventLayouts(for events: [EKEvent], on day: Date) -> [EventLayout] {
        guard !events.isEmpty else { return [] }

        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let hourHeight: CGFloat = 45

        // Sort by real (clamped) start to reduce overlap misses
        let sorted = events.sorted { (a, b) in
            max(a.startDate, dayStart) < max(b.startDate, dayStart)
        }

        var layouts: [EventLayout] = []
        var columns: [[EKEvent]] = []

        func overlaps(_ a: EKEvent, _ b: EKEvent) -> Bool {
            let aStart = max(a.startDate, dayStart)
            let aEnd = min(a.endDate, dayEnd)
            let bStart = max(b.startDate, dayStart)
            let bEnd = min(b.endDate, dayEnd)
            return aStart < bEnd && bStart < aEnd
        }

        for event in sorted {
            var placedIndex: Int?
            for (idx, col) in columns.enumerated() {
                if !col.contains(where: { overlaps(event, $0) }) {
                    placedIndex = idx
                    break
                }
            }
            if placedIndex == nil { columns.append([]); placedIndex = columns.count - 1 }
            columns[placedIndex!].append(event)
        }

        // Build layout frames
        for (colIndex, col) in columns.enumerated() {
            for event in col {
                let start = max(event.startDate, dayStart)
                let end = max(min(event.endDate, dayEnd), start.addingTimeInterval(15*60)) // min 15min
                let comps = calendar.dateComponents([.hour, .minute], from: start)
                let startOffset = (CGFloat(comps.hour ?? 0) + CGFloat(comps.minute ?? 0)/60.0) * hourHeight
                let durationHrs = end.timeIntervalSince(start) / 3600.0
                let height = max(CGFloat(durationHrs) * hourHeight, 30)

                // FIXED: Pass the actual event object
                layouts.append(EventLayout(
                    event: event,
                    column: colIndex,
                    totalColumns: columns.count,
                    startOffset: startOffset,
                    height: height
                ))
            }
        }
        return layouts
    }
}

// MARK: - Calendar List View

struct CalendarListView: View {
    @ObservedObject var calendarManager: CalendarManager
    let onEventTap: (EKEvent) -> Void
    let onEventDelete: (EKEvent) -> Void
    
    private var upcomingEvents: [EKEvent] {
        calendarManager.getUpcomingEvents()
    }
    
    private var groupedEvents: [(key: Date, value: [EKEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: upcomingEvents) { event in
            calendar.startOfDay(for: event.startDate)
        }
        // Sort by date key, then sort events within each group by start time
        return grouped.map { (key: $0.key, value: $0.value.sorted { $0.startDate < $1.startDate }) }
            .sorted { $0.key < $1.key }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                if upcomingEvents.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Text("No Upcoming Events")
                            .font(DesignSystem.Typography.title2)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("You don't have any upcoming events.")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, 60)
                } else {
                    ForEach(groupedEvents, id: \.key) { date, events in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            // Date header
                            HStack {
                                Text(formatDateHeader(date))
                                    .font(DesignSystem.Typography.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Spacer()
                                Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            
                            // Events for this date
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(events, id: \.eventIdentifier) { event in
                                    ListEventRow(
                                        event: event,
                                        onTap: onEventTap,
                                        onDelete: onEventDelete
                                    )
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
            }
            .padding(.top, DesignSystem.Spacing.md)
        }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date()) {
            return "In 2 Days"
        } else {
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - List Event Row

struct ListEventRow: View {
    let event: EKEvent
    let onTap: (EKEvent) -> Void
    let onDelete: (EKEvent) -> Void
    
    private var vm: CalendarEventViewModel { CalendarEventViewModel(event: event) }
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    private var isHappeningNow: Bool {
        let now = Date()
        return event.startDate <= now && event.endDate >= now
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Time indicator
            VStack(alignment: .leading, spacing: 2) {
                if event.isAllDay {
                    Text("All Day")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                } else {
                    Text(Self.timeFormatter.string(from: event.startDate))
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isHappeningNow ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary)
                    
                    if event.startDate != event.endDate {
                        Text(Self.timeFormatter.string(from: event.endDate))
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .frame(width: 70, alignment: .leading)
            
            // Event details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(vm.color)
                        .frame(width: 4, height: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.title)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(2)
                        
                        if let location = vm.location {
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .font(.system(size: 10))
                                Text(location)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        if isHappeningNow {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(DesignSystem.Colors.accent)
                                    .frame(width: 6, height: 6)
                                Text("Happening now")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(vm.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(vm.color.opacity(0.2), lineWidth: 0.5)
                )
        )
        .onTapGesture {
            onTap(event)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete(event)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - All Day Event Card
struct AllDayEventCard: View {
    let event: EKEvent
    let onTap: (EKEvent) -> Void
    let onDelete: (EKEvent) -> Void

    private var vm: CalendarEventViewModel { CalendarEventViewModel(event: event) }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(vm.color).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.title).font(.system(size: 15, weight: .medium)).foregroundColor(.primary).lineLimit(2)
                if let location = vm.location { Text(location).font(.system(size: 13)).foregroundColor(.secondary).lineLimit(1) }
                Text("All Day").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(vm.color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(vm.color.opacity(0.2), lineWidth: 0.5))
        )
        .onTapGesture { onTap(event) }
    }
}

// MARK: - Time Slot Background
struct TimeSlotBackground: View {
    let hour: Int
    let date: Date
    let onTimeSlotTap: (Date) -> Void

    private let hourHeight: CGFloat = 45

    private var timeSlot: TimeSlot { TimeSlot(hour: hour, date: date) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                Text(timeSlot.displayTime)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
                if timeSlot.isCurrentHour {
                    Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                } else {
                    Spacer().frame(width: 6, height: 6)
                }
            }

            Button { onTimeSlotTap(timeSlot.timeDate) } label: {
                Rectangle().fill(Color.clear).frame(height: hourHeight).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .frame(height: hourHeight)
    }
}

// MARK: - Positioned Event View
struct PositionedEventView: View {
    let layout: EventLayout
    let containerWidth: CGFloat
    let date: Date
    let onTap: (EKEvent) -> Void
    let onDelete: (EKEvent) -> Void

    private let timeColumnWidth: CGFloat = 72
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        // FIXED: Use the event directly from layout
        EventCard(event: layout.event, onTap: onTap, onDelete: onDelete)
            .frame(width: calculateWidth(), height: layout.height)
            .offset(x: calculateXOffset(), y: layout.startOffset)
    }

    private func calculateXOffset() -> CGFloat {
        let availableWidth = containerWidth - timeColumnWidth - (horizontalPadding * 2)
        let columnWidth = max(availableWidth / CGFloat(max(layout.totalColumns, 1)), 20)
        return timeColumnWidth + horizontalPadding + (columnWidth * CGFloat(layout.column))
    }

    private func calculateWidth() -> CGFloat {
        let availableWidth = containerWidth - timeColumnWidth - (horizontalPadding * 2)
        let columnWidth = max(availableWidth / CGFloat(max(layout.totalColumns, 1)), 20)
        return columnWidth - 4 // gutter
    }
}


// MARK: - Event Card
struct EventCard: View {
    let event: EKEvent
    let onTap: (EKEvent) -> Void
    let onDelete: (EKEvent) -> Void

    private var vm: CalendarEventViewModel { CalendarEventViewModel(event: event) }

    private var isCompact: Bool {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        return duration / 3600.0 < 0.75
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(vm.color).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(isCompact ? 1 : 3)
                if !isCompact, let location = vm.location {
                    Text(location).font(.system(size: 13)).foregroundColor(.secondary).lineLimit(1)
                }
                EventTimeView(startTime: vm.startTime, endTime: vm.endTime)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(vm.color.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(vm.color.opacity(0.2), lineWidth: 0.5))
        )
        .onTapGesture { onTap(event) }
    }
}

// MARK: - Event Time View
struct EventTimeView: View {
    let startTime: Date
    let endTime: Date

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    var body: some View {
        Text("\(Self.formatter.string(from: startTime)) - \(Self.formatter.string(from: endTime))")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
    }
}

// MARK: - Calendar Event View Model
struct CalendarEventViewModel {
    let event: EKEvent

    var title: String { event.title ?? "Untitled Event" }

    var location: String? {
        guard let s = event.location, !s.isEmpty else { return nil }
        return s
    }

    var color: Color {
        if let cg = event.calendar.cgColor { return Color(cg) }
        return .blue
    }

    var startTime: Date { event.startDate }
    var endTime: Date   { event.endDate }
    var isAllDay: Bool  { event.isAllDay }
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
                Text("Calendar Access Required").font(.title2).fontWeight(.bold)
                Text(accessMessage)
                    .font(.body).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }

            if authorizationStatus == .notDetermined {
                Button("Allow Calendar Access") { onRequestAccess() }
                    .buttonStyle(.borderedProminent)
            } else if isDenied {
                Text("Enable access in Settings > Privacy & Security > Calendars")
                    .font(.caption).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isDenied: Bool {
        if #available(iOS 17, *) {
            return authorizationStatus == .denied || authorizationStatus == .restricted || authorizationStatus == .writeOnly
        } else {
            return authorizationStatus == .denied || authorizationStatus == .restricted
        }
    }

    private var accessMessage: String {
        if #available(iOS 17, *) {
            switch authorizationStatus {
            case .writeOnly: return "Write-only is enabled. To read your events, grant Full Access."
            default: return "To use calendar features, allow access to your events."
            }
        } else {
            return "To use calendar features, allow access to your events."
        }
    }
}

// MARK: - Month Picker View
struct MonthPickerView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private var weekDays: [String] { ["S", "M", "T", "W", "T", "F", "S"] }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(months, id: \.self) { month in
                        VStack(spacing: 12) {
                            Button {
                                selectedDate = month
                                dismiss()
                            } label: {
                                HStack {
                                    Text(Self.dateFormatter.string(from: month))
                                        .font(.title2).fontWeight(.bold).foregroundColor(.primary)
                                    if calendar.isDate(month, equalTo: Date(), toGranularity: .month) {
                                        Text("Current")
                                            .font(.caption)
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(Color.accentColor).foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)

                            VStack(spacing: 8) {
                                HStack(spacing: 0) {
                                    ForEach(weekDays, id: \.self) { day in
                                        Text(day).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                                    ForEach(daysInMonth(month), id: \.self) { date in
                                        if let date = date {
                                            let isSel = calendar.isDate(date, inSameDayAs: selectedDate)
                                            let isToday = calendar.isDateInToday(date)
                                            let dayNumber = calendar.component(.day, from: date)
                                            Button {
                                                selectedDate = date
                                                dismiss()
                                            } label: {
                                                Text("\(dayNumber)")
                                                    .font(.system(size: 14, weight: isSel ? .bold : .medium))
                                                    .foregroundColor(isSel ? .white : (isToday ? .accentColor : .primary))
                                                    .frame(width: 32, height: 32)
                                                    .background(
                                                        Circle().fill(isSel ? Color.accentColor :
                                                                        (isToday ? Color.accentColor.opacity(0.1) : .clear))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            Spacer().frame(width: 32, height: 32)
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
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var months: [Date] {
        let currentDate = Date()
        var out: [Date] = []
        let year = calendar.component(.year, from: currentDate)
        for month in 1...12 {
            if let d = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                out.append(d)
            }
        }
        return out
    }

    private func daysInMonth(_ month: Date) -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        var days: [Date?] = []
        for _ in 1..<firstWeekday { days.append(nil) }
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
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
                            isOn: calendarManager.isCalendarSelected(calendar)
                        ) { newValue in
                            calendarManager.setCalendar(calendar, enabled: newValue)
                        }
                    }
                }
            }
            .navigationTitle("Calendar Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Calendar Toggle Row (real toggle)
struct CalendarToggleRow: View {
    let calendar: EKCalendar
    @State var isOn: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            let color: Color = {
                if let cg = calendar.cgColor { return Color(cg) }
                return .blue
            }()
            Circle().fill(color).frame(width: 12, height: 12)
            Text(calendar.title).foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .onChange(of: isOn) { _, newValue in onToggle(newValue) }
        }
        .contentShape(Rectangle())
        .onTapGesture { isOn.toggle(); onToggle(isOn) }
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
    @State private var selectedCalendarID: String = ""

    private var defaultCalendarID: String {
        calendarManager.store.defaultCalendarForNewEvents?.calendarIdentifier
        ?? calendarManager.allCalendars.first?.calendarIdentifier
        ?? ""
    }

    var isEditing: Bool { event != nil }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Details
                    VStack(spacing: 16) {
                        LabeledField("Event Title") {
                            TextField("Enter event title", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledField("Location") {
                            TextField("Add location (optional)", text: $location)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledField("Notes") {
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                        .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                                )
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .minimalistCard(.elevated)

                    // Time & Date
                    VStack(spacing: 16) {
                        HStack {
                            Text("Time & Date").font(.headline).foregroundColor(.primary)
                            Spacer()
                            Toggle("All Day", isOn: $isAllDay).toggleStyle(SwitchToggleStyle())
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
                    .padding(DesignSystem.Spacing.lg)
                    .minimalistCard(.elevated)

                    // Calendar selection
                    if !calendarManager.allCalendars.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calendar").font(.headline).foregroundColor(.primary)
                            Picker("Calendar", selection: $selectedCalendarID) {
                                ForEach(calendarManager.allCalendars, id: \.calendarIdentifier) { cal in
                                    HStack {
                                        Circle().fill(Color(cal.cgColor)).frame(width: 16, height: 16)
                                        Text(cal.title).foregroundColor(.primary)
                                    }
                                    .tag(cal.calendarIdentifier)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .minimalistCard(.elevated)
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle(isEditing ? "Edit Event" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if isEditing {
                            Button {
                                deleteEvent()
                            } label: {
                                Image(systemName: "trash").foregroundColor(.red)
                            }
                        }
                        Button("Save") { saveEvent() }
                            .fontWeight(.semibold)
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .onAppear { setupInitialValues() }
        // Provide manager to subviews that resolve by ID
        .environmentObject(calendarManager)
        .onDisappear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                calendarManager.loadEvents(center: calendarManager.selectedDate)
            }
        }
    }

    private func setupInitialValues() {
        if let event = event {
            title = event.title ?? ""
            location = event.location ?? ""
            notes = event.notes ?? ""
            startDate = event.startDate
            endDate = event.endDate
            isAllDay = event.isAllDay
            selectedCalendarID = event.calendar.calendarIdentifier
        } else if let start = startTime {
            title = ""
            location = ""
            notes = ""
            startDate = start
            endDate = Calendar.current.date(byAdding: .hour, value: 1, to: start) ?? start
            isAllDay = false
            selectedCalendarID = defaultCalendarID
        } else {
            selectedCalendarID = defaultCalendarID
        }
    }

    private func saveEvent() {
        let cal = Calendar.current
        let eventToSave: EKEvent = event ?? EKEvent(eventStore: calendarManager.store)

        // Choose a writable calendar
        let chosen = calendarManager.allCalendars.first(where: { $0.calendarIdentifier == selectedCalendarID })
        let writable = (chosen?.allowsContentModifications == true) ? chosen
        : calendarManager.store.defaultCalendarForNewEvents
        ?? calendarManager.allCalendars.first(where: { $0.allowsContentModifications })

        guard let useCal = writable else {
            calendarManager.errorMessage = "No writable calendar available."
            return
        }
        eventToSave.calendar = useCal

        eventToSave.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        eventToSave.location = location.isEmpty ? nil : location
        eventToSave.notes = notes.isEmpty ? nil : notes
        eventToSave.isAllDay = isAllDay

        if isAllDay {
            let dayStart = cal.startOfDay(for: startDate)
            eventToSave.startDate = dayStart
            eventToSave.endDate = cal.date(byAdding: .day, value: 1, to: dayStart)!
        } else {
            eventToSave.startDate = startDate
            eventToSave.endDate = endDate > startDate
                ? endDate
                : cal.date(byAdding: .hour, value: 1, to: startDate)!
        }

        do {
            try calendarManager.store.save(eventToSave, span: .thisEvent, commit: true)
            
            // Ensure the calendar containing the event is selected
            if !calendarManager.selectedCalendars.contains(useCal.calendarIdentifier) {
                calendarManager.selectedCalendars.insert(useCal.calendarIdentifier)
            }
            
            // Refresh events after saving - use a broader date range to ensure all events are loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Load events centered on the event's start date or today
                let centerDate = eventToSave.startDate
                calendarManager.loadEvents(center: centerDate)
            }
            dismiss()
        } catch {
            calendarManager.errorMessage = "Save failed: \(error.localizedDescription)"
            calendarManager.debugEventSaving()
        }
    }

    private func deleteEvent() {
        guard let eventToDelete = event else { return }
        calendarManager.deleteEvent(eventToDelete)
        dismiss()
    }
}

// MARK: - Small UI helpers
private struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label; self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline).foregroundColor(.primary)
            content()
        }
    }
}
