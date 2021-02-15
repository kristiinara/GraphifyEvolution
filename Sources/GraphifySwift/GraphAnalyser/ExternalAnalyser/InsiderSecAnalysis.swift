//
//  InsiderSecAnalysis.swift
//  GraphifySwift
//
//  Created by Kristiina Rahkema on 11.02.2021.
//

import Foundation

class InsiderSecAnalysis: ExternalAnalyser {
    let supportedLanguages: [Application.Analyse.Language] = [.swift, .java] // actually ios, android and java
    
    let supportedLevel: Level = .classLevel
    
    let readme: String = "Needs insider from insidersec copied into ./ExternalAnalysers/InsiderSecAnalysis/ folder so that it can be run as ./ExternalAnalysers/InsiderSecAnalysis/insider. Can be run for ios, Android and java. Additional support for javascript and csharp."
    
    let languageUsed: Application.Analyse.Language
    
    var json: [String: Any]?
    var vulnerabilities: [String: [Vulnerability]] = [:]
    
    init(language: Application.Analyse.Language) {
        self.languageUsed = language
    }
    
    func checkIfSetupCorrectly() -> Bool {
        // TODO: add check if insider is present at the correct location
        return true
    }
    
    func analyseApp(app: App) {
        fatalError("InsiderSecAnalysis does not support app level analysis")
    }
    
    func analyseClass(classInstance: Class, app: App) {
        /*
         Run insider
         parse report.json (can we set the path where it is stored?)
         parse libraries (save into db?), if current = latest --> can we find out what it is or is it not necessary? (look into merge request so that no new library objects are added if already exists)
         parse vulnerabilities
            add as objects (again use merge, so that we see if a vulnerability changes)
            classMessage gives full path + line and and column -->
                if (0:0) then class has vulnerability
                if (x:y) then we can link it to a given method --> so find method
                additional parameters:
                    - cvss
                    - cwe
                    - recommendation
                    - vulnerability id? (or is it different for each version, which would make it impossible to merge)
                    - description
         
         additional info about analysis --> add to appVersion?
         "none": 0,
         "low": 5,
         "medium": 2,
         "high": 56,
         "critical": 0,
         "total": 63,
         "ios": {
          "binName": "BrewMobile",
          "averageCvss": 7.5,
          "securityScore": 25,
          "size": "14296180 Bytes",
          "numberOfLines": 122665
         }
         
         */
        
        print("looking for vulnerabilities in class \(classInstance.name) - \(classInstance.path)")
        if self.json == nil {
            let ignore = ["Carthage/*"] // TODO: make it possible to change this
            let appIdentifier = app.appIdentifier
            
            self.analyseFolder(homePath: app.homePath, exclude: ignore, appIdentifier: appIdentifier)
            
            guard let json = self.json else {
                print("No json data available!")
                return
            }
            
            parseVulnerabilities(json: json, app: app)
            
            print("Found duplicates for: \(self.vulnerabilities.keys)")
        }
        
        if let vulnerabilities = self.vulnerabilities[classInstance.path] {
            for vulnerability in vulnerabilities {
                if let line = vulnerability.line {
                    if let method = classInstance.methodAtLineNumber(line: line) {
                        method.relate(to: vulnerability, type: "HAS_VULNERABILITY")
                    } else if let variable = classInstance.variableAtLineNumber(line: line) {
                        variable.relate(to: vulnerability, type: "HAS_VULNERABILITY")
                    } else {
                        print("did not find method or variable at line \(line), relationship to class")
                        classInstance.relate(to: vulnerability, type: "HAS_VULNERABILITY")
                    }
                } else {
                    classInstance.relate(to: vulnerability, type: "HAS_VULNERABILITY")
                }
            }
        }
    }
    
    func reset() {
        self.json = nil
        self.vulnerabilities =  [:]
    }
    
    var techString: String? {
        if languageUsed == .swift {
            return "ios"
        } else if languageUsed == .java {
            return "java"
        } else {
            print("InsiderSecAnalysis does not support language \(languageUsed)")
            return nil
        }
    }
    
    func analyseFolder(homePath: String, exclude: [String], appIdentifier: String) {
        /*
         ./insider --tech ios/android/java --target <folder-path>
         */
        
        if let techString = techString {
            let currentDirectory = FileManager.default.currentDirectoryPath
            
            var path = homePath
            if !path.hasSuffix("/") {
                path = "\(path)/"
            }
            
            var arguments: [String] = [
                "\(currentDirectory)/ExternalAnalysers/InsiderSecAnalysis/insider",
                "-tech", techString,
                "-target", homePath,
                "-no-html"
            ]
            
            
            for value in exclude {
                arguments.append("-exclude")
                arguments.append(value)
            }
            
            let task = Process()
            task.launchPath = "/usr/bin/env"
            task.arguments = arguments
            
            task.launch()
            task.waitUntilExit()
            
            let fileUrl = URL(fileURLWithPath: "\(currentDirectory)/report.json")
            
            let destUrl = URL(fileURLWithPath: "\(currentDirectory)/ExternalAnalysers/InsiderSecAnalysis/reports/\(appIdentifier)/report.json")
            
            do {
                if FileManager.default.fileExists(atPath: destUrl.path) {
                    try FileManager.default.removeItem(at: destUrl)
                }
                
                if FileManager.default.fileExists(atPath: fileUrl.path) {
                    print("report.json found")
                } else {
                    print("report.json does not exist")
                }
                
                if !(FileManager.default.fileExists(atPath: "\(currentDirectory)/ExternalAnalysers/InsiderSecAnalysis/reports/\(appIdentifier)/")) {
                    try FileManager.default.createDirectory(atPath: "\(currentDirectory)/ExternalAnalysers/InsiderSecAnalysis/reports/\(appIdentifier)/", withIntermediateDirectories: true, attributes: [:])
                }
                
                try FileManager.default.copyItem(at: fileUrl, to: destUrl)
            } catch (let error) {
                print("InsiderSecAnalysis: cannot copy item at \(fileUrl) to \(destUrl): \(error)")
                fatalError("InsiderSecAnalysis: cannot copy item at \(fileUrl) to \(destUrl): \(error)")
            }
            
            self.json = JsonHandler.jsonFromPath(path:destUrl.path)
        } else {
            print("Invalid techstring, cannot run insider")
        }
    }
    
    func parseVulnerabilities(json: [String: Any], app:App) {
        guard let vulnerabilities = json["vulnerabilities"] as? [[String: Any]] else {
            print("No vulnerability in data!")
            return
        }
        
        /* // we get library data when detecting vulnerabilities, but we do not always run the scanner if it is implemented as class based
         // due to performance reasons it does not make sense to run the whole vulnerability scanner if there were no changed classes. Removing library analysis also allows us to exclude Carthage paths from analysis, which again improves performance
        if let libraries = json["libraries"] as? [[String: Any]] {
            for library in libraries {
                if let name = library["name"] as? String,
                   let version = library["current"] as? String {
                    let newLibrary = Library(name: name, version: version)
                    let _ = app.relate(to: newLibrary, type: "USES_LIBRARY")
                    print("app uses library: \(newLibrary.name)")
                } else {
                    print("could not parse library: \(library)")
                }
            }
        }
        */
        
        for vulnerability in vulnerabilities {
            if
                let cvss = vulnerability["cvss"] as? Float,
                let cwe = vulnerability["cwe"] as? String,
                let description = vulnerability["description"] as? String,
                let classMessage = vulnerability["classMessage"] as? String,
                let recommendation = vulnerability["recomendation"] as? String {
                
                let line = vulnerability["line"] as? Int
                let method = vulnerability["method"] as? String
                
                var classPath = String(classMessage.split(separator: " ").first!)
                if app.homePath.hasSuffix("/") {
                    classPath = "\(app.homePath)\(classPath)"
                } else {
                    classPath = "\(app.homePath)/\(classPath)"
                }
                
                let newVulnerability = Vulnerability(cvss: cvss, cwe: cwe, line: line, method: method, description: description, classPath: classPath, recommendation: recommendation)
                
                var vulnerabilities: [Vulnerability] = []
                    
                if let list = self.vulnerabilities[classPath] {
                    vulnerabilities = list
                }
                    
                vulnerabilities.append(newVulnerability)
                self.vulnerabilities[classPath] = vulnerabilities
            }
        }
    }
}

class Vulnerability {
    
    let cvss: Float
    let cwe: String
    let line: Int?
    let method: String?
    let description: String
    let classPath: String
    let recommendation: String
    
    init(cvss: Float, cwe: String, line: Int?, method: String?, description: String, classPath: String, recommendation: String) {
        self.cvss = cvss
        self.cwe = cwe
        self.line = line
        self.method = method
        self.description = description
        self.classPath = classPath
        self.recommendation = recommendation
    }
    
    var nodeSet: Node?
}

extension Vulnerability: Neo4jObject {
    typealias ObjectType = Vulnerability
    static var nodeType = "Vulnerability"
    
    var properties: [String: Any] {
        var properties: [String: Any]
        
        if let node = self.nodeSet {
            properties = node.properties
        } else {
            properties = [:]
        }
        
        properties["cvss"] = cvss
        properties["cwe"] = cwe
        properties["line"] = line
        if let method = self.method {
            properties["method"] = "'\(method.replacingOccurrences(of: "\'", with: "\""))'"
        } else {
            properties["method"] = self.method
        }
        properties["description"] = description
        properties["classPath"] = classPath
        properties["recommendation"] = recommendation
        
        return properties
    }
    
    var updatedNode: Node {
        let oldNode = self.node
        oldNode.properties = self.properties
        
        self.nodeSet = oldNode
        
        return oldNode
    }
    
    var node: Node {
        if nodeSet == nil {
            var newNode = Node(label: Self.nodeType, properties: self.properties)
            newNode = self.newNodeWithMerge(node: newNode)
            nodeSet = newNode
        }
        
        return nodeSet!
    }
}

/*
class Library {
    let name: String
    let version: String
    //let source: String
    
    init(name: String, version: String) {
        self.name = name
        self.version = version
    }
    
    var nodeSet: Node?
}

extension Library: Neo4jObject {
    typealias ObjectType = Library
    static var nodeType = "Library"
    
    var properties: [String: Any] {
        var properties: [String: Any]
        
        if let node = self.nodeSet {
            properties = node.properties
        } else {
            properties = [:]
        }
        
        properties["name"] = self.name
        properties["version"] = self.version
        
        return properties
    }
    
    var updatedNode: Node {
        let oldNode = self.node
        oldNode.properties = properties
        
        self.nodeSet = oldNode
        
        return oldNode
    }
    
    var node: Node {
        if nodeSet == nil {
            var newNode = Node(label: Self.nodeType, properties: self.properties)
            newNode = self.newNodeWithMerge(node: newNode)
            nodeSet = newNode
        }
        
        return nodeSet!
    }
}
 */
