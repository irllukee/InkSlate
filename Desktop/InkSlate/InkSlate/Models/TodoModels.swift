//
//  TodoModels.swift
//  InkSlate
//
//  Created by UI Overhaul on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Todo Data Models

@Model
class TodoTab {
    var name: String = "New Tab"
    var colorHex: String = "#99CCFF"
    var createdDate: Date = Date()
    @Relationship(deleteRule: .cascade) var tasks: [TodoTask]? = []
    
    var color: Color {
        get { Color(hex: colorHex) ?? Color.blue }
        set { colorHex = newValue.toHex() }
    }
    
    init(name: String, color: Color) {
        self.name = name
        self.colorHex = color.toHex()
    }
}

@Model
class TodoTask {
    var title: String = "New Task"
    var taskDescription: String = ""
    var isCompleted: Bool = false
    var createdDate: Date = Date()
    var completedDate: Date = Date.distantPast
    @Relationship(deleteRule: .nullify, inverse: \TodoTab.tasks) var tab: TodoTab?
    
    init(title: String = "New Task", description: String = "", isCompleted: Bool = false) {
        self.title = title
        self.taskDescription = description
        self.isCompleted = isCompleted
    }
}

