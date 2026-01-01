//
//  Item.swift
//  workout
//
//  Created by 間山友喜 on 2026/01/01.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
