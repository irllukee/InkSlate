//
//  Item.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date = Date()
    
    init(timestamp: Date = Date()) {
        self.timestamp = timestamp
    }
}
