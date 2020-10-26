//
//  CPPFileManager.swift
//  
//
//  Created by Kristiina Rahkema on 26.10.2020.
//

import Foundation

class CPPFileManager: LocalFileManager {
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
        
        let ignore: [String] = []
        
        fileLoop: for case let fileURL as URL in enumerator {
            // ignoring files that contain the ignore string, but only looking at path relative to after the base url
            for ignorePath in ignore {
                var path = fileURL.path
                path = path.replacingOccurrences(of: url.path, with: "")
                if path.contains(ignorePath) {
                    continue fileLoop
                }
            }
            
            if fileURL.path.contains("+") {
                continue fileLoop
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                //print(fileURL.path, resourceValues.creationDate!, resourceValues.isDirectory!)
                
                if let name = resourceValues.name {
                    if name.hasSuffix(".cpp") || name.hasSuffix(".h") {
                        //let size = resourceValues.fileSize!
                        //print("\(fileURL.path)")
                        //self.app.size = self.app.size + size
                        //TODO: fix size stuff
                        //self.classSizes.append(size)
                        
                         if (fileURL.path.contains("Tests")) {
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
