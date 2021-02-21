//
//  JavaFileManager.swift
//  GraphifySwift
//
//  Created by Kristiina Rahkema on 01.02.2021.
//

import Foundation
class JavaFileManager: LocalFileManager {
    
    var ignoreWithPathComponents: [String] {
        return ["/test/"]
    }
    
    var allowedEndings: [String] {
        return [".java"]
    }
    
    func fetchProjectFiles(folderPath: String) -> [URL] {
        return fetchAllFiles(folderPath: folderPath)
    }
    
    func fetchAllFiles(folderPath: String) -> [URL] {
        var files: [URL] = []
        
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
        
        let ignore: [String] = self.ignoreWithPathComponents
        
        fileLoop: for case let fileURL as URL in enumerator {
            // ignoring files that contain the ignore string, but only looking at path relative to after the base url
            for ignorePath in ignore {
                var path = fileURL.path
                path = path.replacingOccurrences(of: url.path, with: "")
                if path.contains(ignorePath) {
                    continue fileLoop
                }
            }
            
            /*
            if !(fileURL.path.contains("/src/") || fileURL.path.contains("/include/")) {
                continue fileLoop
            }
 */
        
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                //print(fileURL.path, resourceValues.creationDate!, resourceValues.isDirectory!)
                
                if let name = resourceValues.name {
                    if name.hasSuffix(".java") {
                        //let size = resourceValues.fileSize!
                        //print("\(fileURL.path)")
                        //self.app.size = self.app.size + size
                        //TODO: fix size stuff
                        //self.classSizes.append(size)
                        
                         if (fileURL.path.contains("/test/")) {
                            //print("Ignore test files")
                        } else {
                            files.append(fileURL)
                        }
                    }
                }
            } catch {
                //TODO: do something if an error is thrown!
                print("Error")
            }
        }
        return files
    }
}
