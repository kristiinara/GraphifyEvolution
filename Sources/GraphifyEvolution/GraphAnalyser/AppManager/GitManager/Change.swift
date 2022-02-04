//
//  Change.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

class Change {
    enum ChangeType {
        case changed, added, removed, confused
    }
    
    var type: ChangeType {
        if oldLines == nil && newLines == nil {
            return .confused
        }
        
        if oldLines == nil {
            return .added
        }
        
        if newLines == nil {
            return .removed
        }
        
        return .changed
    }
    var oldLines: (start: Int, length: Int)?
    var newLines: (start: Int, length: Int)?
    
    init(oldLines: (start: Int, length: Int?), newLines: (start: Int, length: Int?)) {
        if let oldLength = oldLines.length {
            self.oldLines = (start: oldLines.start, length: oldLength)
        }
        
        if let newLength = newLines.length {
            self.newLines = (start: newLines.start, length: newLength)
        }
    }
}
