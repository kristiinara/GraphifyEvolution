//
//  CPPSyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import SourceKittenFramework

class CPPSyntaxAnalyser: SyntaxAnalyser {
    var result: String?
    var classes: [String:[Class]]?
    
    func reset() {
        result = nil
        classes = nil
    }
    
    func analyseFile(filePath: String, includePaths: [String]) -> [Class] {
        print("analyseFile \(filePath)")
        
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
                    if let classInstance = parseClassFrom(json: item) {
                        if self.classes == nil {
                            self.classes = [:]
                        }
                        
                        var classesForPath: [Class] = []
                        
                        if let existingClassesForPath = self.classes![classInstance.path] {
                            classesForPath = existingClassesForPath
                        }
                        
                        classesForPath.append(classInstance)
                        self.classes![classInstance.path] = classesForPath
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
