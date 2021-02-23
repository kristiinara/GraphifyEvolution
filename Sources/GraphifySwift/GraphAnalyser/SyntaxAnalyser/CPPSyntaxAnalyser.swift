//
//  CPPSyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import SourceKittenFramework

class CPPSyntaxAnalyser: SyntaxAnalyser {
    let constants: Kind = SwiftKind() // TODO: change this later, currently analyse.py enters swift like keys
    var result: String?
    var classes: [String:[Class]]?
    
    func reset() {
        result = nil
        classes = nil
    }
    
    func analyseFile(filePath: String, includePaths: [String]) -> [Class] {
        print("analyseFile \(filePath)")
        
        if !includePaths.contains(filePath) {
            print("Filepath \(filePath) not in includePaths: \(includePaths)")
            return []
        }
        
        if classes == nil {
            var directoryPath: String? = nil
            if filePath.contains("/src/") {
                directoryPath = String(filePath.components(separatedBy: "/src/")[0])
            }
            
            if filePath.contains("/include/") {
                directoryPath = String(filePath.components(separatedBy: "/include/")[0])
            }
            
            if let directoryPath = directoryPath {
                runPythonCommand(path: "\(directoryPath)/")
            }
        }
        
        if let classes = classes {
            if let classesForFile = classes[filePath] {
                return classesForFile
            } else {
                var alternatePath = filePath
                if filePath.contains("/src/") {
                    alternatePath = alternatePath.replacingOccurrences(of: "/src/", with: "/include/")
                    alternatePath = alternatePath.replacingOccurrences(of: ".cpp", with: ".h")
                } else if filePath.contains("/include/") {
                    alternatePath = alternatePath.replacingOccurrences(of: "/include/", with: "/src/")
                    alternatePath = alternatePath.replacingOccurrences(of: ".h", with: ".cpp")
                }
                
                if let classesForFile = classes[alternatePath] {
                    return classesForFile
                }
                
                if filePath.hasSuffix("main.cpp") || filePath.contains("inpututils") || filePath.contains("functions") {
                    //ignore right now
                    //TODO: figure out if we should add as separate class
                    return []
                }
                
                print("no classes for filepath: \(filePath) or alternatePath: \(alternatePath), allClasses: \(classes)")
                //fatalError("no classes for filepath: \(filePath) or alternatePath: \(alternatePath), allClasses: \(classes)")
            }
        }
        return []
    }
    
    func runPythonCommand(path: String){
        let currentDirectory = FileManager.default.currentDirectoryPath
        print("run python: \(currentDirectory)/PythonCppAnalyser/analyse.py")
        
        let res = Helper.shell(launchPath: "/usr/bin/python", arguments:
            ["\(currentDirectory)/PythonCppAnalyser/analyse.py", path])
        var json = res
        
        let decoder = JSONDecoder()

        do {
            
            print("--------- json:")
            print("json: \(json)")
            
            if let data = json.data(using: .utf8) {
              let myJson = try JSONSerialization.jsonObject(with: data,
                                                            options: JSONSerialization.ReadingOptions.mutableContainers) as Any

              if let items = myJson as? [[String: Any]] {
                for item in items {
                    print("json item: \(item)")
                    if let classInstance = parseClassFrom(json: item, path: path) {
                        var classes: [String: [Class]]
                        
                        if let existing = self.classes {
                            classes = existing
                        } else {
                            classes = [:]
                        }
                        
                        var classesForPath: [Class] = []
                        
                        if let existingClassesForPath = classes[classInstance.path] {
                            classesForPath = existingClassesForPath
                        }
                        
                        classesForPath.append(classInstance)
                        classes[classInstance.path] = classesForPath
                        
                        self.classes = classes
                    }
                }
              }
            }
            
                    
        } catch {
            print("json failed")
            print("\(json)")
            fatalError("Cannot parse json from c++ python analyser - \(error.localizedDescription)")
        }
    }
}
