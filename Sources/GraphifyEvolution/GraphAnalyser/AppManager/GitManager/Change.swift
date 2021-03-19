//
//  Change.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation

class Change {
    enum ChangeType {
        case changed, added, removed, confused
    }
    
    var type: ChangeType {
        if oldLines.length == 0 && newLines.length == 0 {
            return .confused
        } else if oldLines.length == 0 {
            return .added
        } else if newLines.length == 0 {
            return .removed
        } else {
            return .changed
        }
    }
    var oldLines: (start: Int, length: Int)
    var newLines: (start: Int, length: Int)
    
    init(oldLines: (start: Int, length: Int), newLines: (start: Int, length: Int)) {
        self.oldLines = oldLines
        self.newLines = newLines
    }
}
