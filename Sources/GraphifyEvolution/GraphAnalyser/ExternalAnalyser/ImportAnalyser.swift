//
//  ImportAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 01.07.2022.
//

import Foundation

class ImportAnalyserClass: ExternalAnalyser {
    func analyseApp(app:App) {
        fatalError("DuplicationAnalyser does not support app level analysis")
    }
    func analyseClass(classInstance:Class, app:App) {
        let filePath = classInstance.path
        
        if let contents = try? String(contentsOfFile: filePath) {
            for line in contents.components(separatedBy: .newlines) {
                if line.starts(with: "import") {
                    let parts = line.components(separatedBy: .whitespaces)
                    if parts.count >= 2 {
                        let name = parts[1]
                        let newStatement = ImportStatement(name: name)
                        newStatement.save()
                        classInstance.relate(to: newStatement, type: "IMPORTS")
                    }
                }
            }
        }
    }
    func reset() {
        
    }
    
    func checkIfSetupCorrectly() -> Bool {
        return true
    }
    
    var supportedLanguages: [Application.Analyse.Language] = [.swift]
    var supportedLevel: Level = .classLevel
    var readme = "Finds import statements for given class and records them in the database."
}

class ImportAnalyser: ExternalAnalyser {
    func analyseApp(app:App) {
        let enumerator = FileManager.default.enumerator(atPath: app.homePath)
        while let filename = enumerator?.nextObject() as? String {
            if filename.hasSuffix(".swift") {
                let filePath = "\(app.homePath)/\(filename)"
                if let contents = try? String(contentsOfFile: filePath) {
                    for line in contents.components(separatedBy: .newlines) {
                        if line.starts(with: "import") {
                            let parts = line.components(separatedBy: .whitespaces)
                            if parts.count >= 2 {
                                let name = parts[1]
                                let newStatement = ImportStatement(name: name)
                                newStatement.save()
                                app.relate(to: newStatement, type: "IMPORTS")
                            }
                        }
                    }
                }
            }
        }
    }
    func analyseClass(classInstance:Class, app:App) {
        fatalError("DuplicationAnalyser does not support class level analysis")
    }
    func reset() {
        
    }
    
    func checkIfSetupCorrectly() -> Bool {
        return true
    }
    
    var supportedLanguages: [Application.Analyse.Language] = [.swift]
    var supportedLevel: Level = .applicationLevel
    var readme = "Finds import statements for given class and records them in the database."
}

class ImportStatement {
    var name: String
    
    init(name: String) {
        self.name = name
    }
    
    var nodeSet: Node?
}

extension ImportStatement: Neo4jObject {
    typealias ObjectType = ImportStatement
    static var nodeType = "ImportStatement"
    
    var properties: [String: Any] {
        var properties: [String: Any]
        
        if let node = self.nodeSet {
            properties = node.properties
        } else {
            properties = [:]
        }
        
        properties["name"] = self.name
        
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

