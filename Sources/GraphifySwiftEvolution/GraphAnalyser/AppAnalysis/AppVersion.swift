//
//  AppVersion.swift
//  
//
//  Created by Kristiina Rahkema on 26.10.2020.
//

import Foundation

class AppVersion {
    var children: [AppVersion] = []
    var parent: AppVersionParent?
    var alternateParent: AppVersionParent?
    var directoryPath: String
    var commit: Commit?
    var appKey: String?
    var changedFilePaths: [String]? { //TODO: check where we are using this and if it makes sense! (also how about if it is a  merge!)
        var paths: [String] = []
        
        if let parent = self.parent {
            for change in parent.changes {
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
    
    var analysedVersion: App?
    
    var isMerge: Bool {
        if self.parent != nil && self.alternateParent != nil {
            return true
        }
        return false
    }
    
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

class AppVersionParent {
    let appVersion: AppVersion
    let changes: [FileChange]
    let addedPaths: [String]
    let removedPaths: [String]
    let changedPaths: [String]
    let renamedPaths: [String:String]
    let changesForPaths: [String:[FileChange]]
    
    init(appVersion: AppVersion, changes: [FileChange]) {
        self.appVersion = appVersion
        self.changes = changes
        
        var addedPaths: [String] = []
        var removedPaths: [String] = []
        var changedPaths: [String] = []
        var renamedPaths: [String: String] = [:]
        var changesForPaths: [String:[FileChange]] = [:]
        
        for fileChange in changes {
            //print("change for files: \(fileChange.oldPath) - \(fileChange.newPath)")
            
            if fileChange.type == .removed {
                //print("change: removed")
                
                if let oldPath = fileChange.oldPath {
                    removedPaths.append(oldPath)
                } else {
                    print("No oldPath for removed file")
                }
                
                continue
            }
            
            if fileChange.type == .renamed {
                //print("change: renamed")
                if let oldPath = fileChange.oldPath, let newPath = fileChange.newPath {
                    renamedPaths[oldPath] = newPath
                } else {
                    print("No newPath or oldPath for renamed file")
                }
                
                continue
            }
            
            if fileChange.type == .added {
                //print("change: added")
                if let newPath = fileChange.newPath {
                    addedPaths.append(newPath)
                } else {
                    print("No newPath for new file")
                }
                
                continue
            }
            
            if fileChange.type == .changed {
                //print("change: changed")
                
                if let newPath = fileChange.newPath {
                    changedPaths.append(newPath)
                
                    var changesOnpath: [FileChange] = []
                
                    if let existingChanges = changesForPaths[newPath] {
                        changesOnpath = existingChanges
                    }
                
                    changesOnpath.append(fileChange)
                    changesForPaths[newPath] = changesOnpath
                } else {
                    print("No newPath for changed file")
                }
                
                //TODO: can it happen that something is changed and renamed?
                continue
            }
        }
        
        self.addedPaths = addedPaths
        self.removedPaths = removedPaths
        self.changedPaths = changedPaths
        self.renamedPaths = renamedPaths
        self.changesForPaths = changesForPaths
    }
    
    var unchangedPaths: [String] {
        if let app = self.appVersion.analysedVersion {
            let classes = app.classes
            let classPaths = classes.map() { classInstance in return classInstance.path }
            
            var unchanged: [String] = []
            
            for path in classPaths {
                if self.addedPaths.contains(path) {
                    continue
                }
                if self.removedPaths.contains(path) {
                    continue
                }
                if self.changedPaths.contains(path) {
                    continue
                }
                // TODO: what about renamed paths?
                
                unchanged.append(path)
            }
            
            return unchanged
        }
        
        return []
    }
    
}
