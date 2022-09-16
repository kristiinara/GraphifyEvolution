//
//  Change.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

class Change: Codable {
    enum ChangeType: Codable {
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
   // var oldLines: (start: Int, length: Int)?
   // var newLines: (start: Int, length: Int)?
    
    var oldLines: LineInterval?
    var newLines: LineInterval?
    
    init(oldLines: (start: Int, length: Int?), newLines: (start: Int, length: Int?)) {
        if let oldLength = oldLines.length {
            self.oldLines = LineInterval(start: oldLines.start, length: oldLength)
        }
        
        if let newLength = newLines.length {
            self.newLines = LineInterval(start: newLines.start, length: newLength)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case oldLines
        case newLines
    }
}

struct LineInterval: Codable {
    var start: Int
    var length: Int
    
    init(start: Int, length: Int) {
        self.start = start
        self.length = length
    }
}
