//
//  FileChange.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

class FileChange: Codable {
    enum FileChangeType: Codable {
        case changed, added, removed, renamed
    }
    
    var oldPath: String?
    var newPath: String?
    var changes: [Change] = []
    
    var type: FileChangeType {
        if oldPath == nil {
            return .added
        }
        if newPath == nil {
            return .removed
        }
        
        if oldPath != newPath {
            return .renamed
        }
        
        return .changed
    }
    
    init(oldPath: String?, newPath: String?) {
        self.oldPath = oldPath
        self.newPath = newPath
    }
}
