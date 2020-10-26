//
//  AppVersion.swift
//  
//
//  Created by Kristiina Rahkema on 26.10.2020.
//

import Foundation

class AppVersion {
    var children: [AppVersion] = []
    var parent: AppVersion?
    var alternateParent: AppVersion?
    var directoryPath: String
    var commit: String?
    var changedFilePaths: [String]? {
        var paths: [String] = []
        
        if let changes = self.changes {
            for change in changes {
                if let newPath = change.newPath {
                    //TODO: fix this! Currently too ugly and won't work with all projects
                    paths.append("\(self.directoryPath.dropLast(".git".count))\(newPath)")
                }
            }
        } else {
            return nil
        }
        return paths
    }
    
    var changes: [FileChange]?
    
    var analysedVersion: App?
    
    init(directoryPath: String) {
        self.directoryPath = directoryPath
    }
    
    var first: Bool {
        return self.parent == nil
    }
    
    var analysed: Bool {
        return self.analysedVersion == nil
    }
}
