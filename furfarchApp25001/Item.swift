//
//  Item.swift
//  SimplyDrive
//
//  Created by Chris Furfari on 27.12.2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date = Date.now
    
    init(timestamp: Date = Date.now) {
        self.timestamp = timestamp
    }
}
