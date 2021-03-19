//
//  DuplicationAnalyser.swift
//  GraphifySwift
//
//  Created by Kristiina Rahkema on 08.02.2021.
//

import Foundation

class DuplicationAnalyser: ExternalAnalyser {
    
    let supportedLanguages: [Application.Analyse.Language] = [.swift, .cpp, .java]
    let supportedLevel: Level = .classLevel
    let readme = "Requires jscpd to be installed."
    
    var json: [String: Any]?
    
    var duplicates: [String: [Duplication]] = [:]
    var handledDuplicates: [Int] = []
    
    func reset() {
        self.json = nil
        self.duplicates = [:]
        self.handledDuplicates = []
    }
    
    func checkIfSetupCorrectly() -> Bool {
        // TODO: add check to see if jscpd is installed
        return true
    }
    
    func analyseApp(app: App) {
        fatalError("DuplicationAnalyser does not support app level analysis")
    }
    
    func analyseClass(classInstance: Class, app: App) {
        print("looking for duplicates in class \(classInstance.name) - \(classInstance.path)")
        if self.json == nil {
            let ignore = [".build/**","**/Carthage/**"] // TODO: make it possible to change this
            let appIdentifier = app.appIdentifier
            
            analyseFolder(homePath: app.homePath, ignore: ignore, appIdentifier: appIdentifier)
            
            guard let json = self.json else {
                print("No json data available!")
                return
            }
            
            guard let duplicates = json["duplicates"] as? [[String: Any]] else {
                print("No duplicates in data!")
                return
            }
            
            print("Duplication analysis done, json: \(json)")
            
            parseDuplicates(json: duplicates)
            print("Found duplicates for: \(self.duplicates.keys)")
        }
        
        if let duplicates = self.duplicates[classInstance.path] {
            duplicateLoop: for duplicate in duplicates {
                if self.handledDuplicates.contains(duplicate.number) {
                    print("duplication already handled")
                    continue duplicateLoop
                }
                
                var classDuplicateStartEnd = (start: duplicate.startLineFirstFile, end: duplicate.endLineFirstFile)
                var otherClassDuplicateStartEnd = (start: duplicate.startLineSecondFile, end: duplicate.endLineSecondFile)
                var otherFilepath = duplicate.secondFilePath
                
                if duplicate.secondFilePath == classInstance.path {
                    classDuplicateStartEnd = (start: duplicate.startLineSecondFile, end: duplicate.endLineSecondFile)
                    otherClassDuplicateStartEnd = (start: duplicate.startLineFirstFile, end: duplicate.endLineFirstFile)
                    otherFilepath = duplicate.firstFilePath
                }
                
                let classStartEnd = classInstance.minMaxLineNumbers
                if classStartEnd.min > classDuplicateStartEnd.end {
                    continue duplicateLoop
                }
                if classStartEnd.max < classDuplicateStartEnd.start {
                    continue duplicateLoop
                }
                
                var foundOtherClass: Class?
                
                classLoop: for otherClass in app.classes {
                    if otherClass.path == otherFilepath {
                        let otherClassStartEnd = otherClass.minMaxLineNumbers
                        
                        if otherClassStartEnd.min > classDuplicateStartEnd.end {
                            continue classLoop
                        }
                        if otherClassStartEnd.max < classDuplicateStartEnd.start {
                            continue classLoop
                        }
                        foundOtherClass = otherClass
                    }
                }
                
                if let otherClass = foundOtherClass {
                    classInstance.relate(to: otherClass, type: "DUPLICATES", properties: ["fragment": duplicate.codeFragment])
                } else {
                    print("No matching class found for duplicate paths: \(duplicate.firstFilePath), \(duplicate.secondFilePath) -- class: \(classInstance.name)")
                }
                
            }
        } else {
            print("no duplicates for class \(classInstance.name), path: \(classInstance.path)")
        }
    }
    
    func analyseFolder(homePath: String, ignore: [String], appIdentifier: String) {
        var path = homePath
        if !path.hasSuffix("/") {
            path = "\(path)/"
        }
        
        let currentDirectory = FileManager.default.currentDirectoryPath
        
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = [
            "jscpd",
            homePath,
            "--min-tokens", "10",
            "--format", "swift",
            "--reporters", "json",
            "--absolute",
            "--output", "\(currentDirectory)/ExternalAnalysers/DuplicationAnalyser/reports/\(appIdentifier)/",
            "--ignore ", ignore.joined(separator: ",")
        ]
        task.launch()
        task.waitUntilExit()
        
        self.json = JsonHandler.jsonFromPath(path:"\(currentDirectory)/ExternalAnalysers/DuplicationAnalyser/reports/\(appIdentifier)/jscpd-report.json")
    }
    
    func parseDuplicates(json: [[String: Any]]) {
        var count = 0
        
        for duplicate in json {
            if let firstFile = duplicate["firstFile"] as? [String: Any], let secondFile = duplicate["secondFile"] as? [String: Any] {
                
                if let firstFilePath = firstFile["name"] as? String,
                    let secondFilePath = secondFile["name"] as? String,
                    let firstfileStart = firstFile["start"] as? Int,
                    let secondfileStart = secondFile["start"] as? Int,
                    let firstfileEnd = firstFile["end"] as? Int,
                    let secondfileEnd = secondFile["end"] as? Int,
                    let fragment = duplicate["fragment"] as? String {
                    
                    let newDuplicate = Duplication(firstFilePath: firstFilePath, secondFilePath: secondFilePath, startLineFirstFile: firstfileStart, endLineFirstFile: firstfileEnd, startLineSecondFile: secondfileStart, endLineSecondFile: secondfileEnd, codeFragment: fragment, number: count)
                    count += 1
                    
                    var firstDuplicates: [Duplication] = []
                    
                    if let duplicates = self.duplicates[firstFilePath] {
                        firstDuplicates = duplicates
                    }
                    
                    firstDuplicates.append(newDuplicate)
                    self.duplicates[firstFilePath] = firstDuplicates
                    
                    if firstFilePath != secondFilePath {
                        var secondDuplicates: [Duplication] = []
                        
                        if let duplicates = self.duplicates[secondFilePath] {
                            secondDuplicates = duplicates
                        }
                        
                        secondDuplicates.append(newDuplicate)
                        self.duplicates[secondFilePath] = secondDuplicates
                    }
                } else {
                    print("Could not add duplication, some values were nil")
                }
            } else {
                print("Could not find fristFile and/or secondFile")
            }
        }
    }
}

class Duplication {
    let firstFilePath: String
    let secondFilePath: String
    let startLineFirstFile: Int
    let endLineFirstFile: Int
    let startLineSecondFile: Int
    let endLineSecondFile: Int
    let codeFragment: String
    let number: Int
    
    init(firstFilePath: String, secondFilePath: String, startLineFirstFile: Int, endLineFirstFile: Int, startLineSecondFile: Int, endLineSecondFile: Int, codeFragment: String, number: Int) {
        self.firstFilePath = firstFilePath
        self.secondFilePath = secondFilePath
        self.startLineFirstFile = startLineFirstFile
        self.endLineFirstFile = endLineFirstFile
        self.startLineSecondFile = startLineSecondFile
        self.endLineSecondFile = endLineSecondFile
        self.codeFragment = codeFragment
        self.number = number
    }
}
