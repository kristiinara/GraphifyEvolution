//
//  SwiftFileManager.swift
//  
//
//  Created by Kristiina Rahkema on 26.10.2020.
//

import Foundation

class SwiftFileManager: LocalFileManager {
    let dependencyManager: DependencyManager
    
    var ignoreWithPathComponents: [String] {
        return self.dependencyManager.ignoreWithPathComponents
    }
    
    var allowedEndings: [String] {
        return [".swift"]
    }
    
    init(dependencyManager: DependencyManager) {
        self.dependencyManager = dependencyManager
    }
    
    func fetchProjectFiles(folderPath: String) -> [URL] {
        return fetchAllFiles(folderPath: folderPath, ignore: self.ignoreWithPathComponents)
    }
    
    func fetchAllFiles(folderPath: String) -> [URL] {
        return fetchAllFiles(folderPath: folderPath, ignore: [])
    }
    
    func fetchAllFiles(folderPath: String, ignore: [String]) -> [URL] {
        var files: [String: URL] = [:]
        var atLeastOneSwiftFile = false
        
        let resourceKeys : [URLResourceKey] = [
            .creationDateKey,
            .isDirectoryKey,
            .nameKey,
            .fileSizeKey
        ]
        
        let url = URL(fileURLWithPath: folderPath)
        
        let enumerator = FileManager.default.enumerator(
            at:                         url,
            includingPropertiesForKeys: resourceKeys,
            options:                    [.skipsHiddenFiles],
            errorHandler:               { (url, error) -> Bool in
                print("directoryEnumerator error at \(url): ", error)
                return true
        })!
        
        fileLoop: for case let fileURL as URL in enumerator {
            // ignoring files that contain the ignore string, but only looking at path relative to after the base url
            for ignorePath in ignore {
                var path = fileURL.path
                path = path.replacingOccurrences(of: url.path, with: "")
                if path.contains(ignorePath) {
                    continue fileLoop
                }
            }
            
//            if fileURL.path.contains("+") {
//                continue fileLoop
//            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                //print(fileURL.path, resourceValues.creationDate!, resourceValues.isDirectory!)
                
                if let name = resourceValues.name {
                    if name.hasSuffix(".swift") || name.hasSuffix(".h") {
                        if name.hasSuffix(".swift") {
                            atLeastOneSwiftFile = true
                        }
                        
                        //let size = resourceValues.fileSize!
                        //print("\(fileURL.path)")
                        //self.app.size = self.app.size + size
                        //TODO: fix size stuff
                        //self.classSizes.append(size)
                        
                        if (fileURL.path.contains("Tests") ||  fileURL.path.contains("TestCase")) {
                            //print("Ignore test files")
//                         } else if ((fileURL.path.contains("Example") || fileURL.path.contains("Externals"))  && fileURL.path.contains("Carthage")) {
//                            // ignore
//                         } else if fileURL.path.components(separatedBy: "/Carthage/Checkouts/").count > 2 {
//                            // ignore (carthage checkouts of charthage checkouts)
                         } else {
                            if let existingURL = files[name] {
                                if existingURL.path.contains("Carthage") {
                                    files[name] = fileURL
                                } else {
                                    // ignore, sometimes the same file exists in multiple libraries
                                }
                            } else {
                                files[name] = fileURL
                            }
                        }
                    }
                }
            } catch {
                //TODO: do something if an error is thrown!
                print("Error")
            }
        }
        if (atLeastOneSwiftFile) {
            return [URL] (files.values)
        } else {
            return []
        }
    }
}
