//
//  File.swift
//  
//
//  Created by Kristiina Rahkema on 01.07.2022.
//

import Foundation

class LanguageAnayser: ExternalAnalyser {
    let databaseController = DatabaseController.currentDatabase
    
    func analyseApp(app:App) {
        var dict: [String: Int] = [:]
        
        let enumerator = FileManager.default.enumerator(atPath: app.homePath)
        while let filename = enumerator?.nextObject() as? String {
            if filename.starts(with: ".") {
                continue // ignore all hidden .git and .gitignore files
            }
            
            if filename.contains(".") {
                var fileEnding:String = String(filename.split(separator: ".").last!)
                fileEnding = fileEnding.trimmingCharacters(in: .whitespacesAndNewlines)
            
                if let count = dict[fileEnding] {
                    dict[fileEnding] = count + 1
                } else {
                    dict[fileEnding] = 1
                }
            }
        }
        
        for key in dict.keys {
            let language = Language(name: key)
            language.save()
            
            app.relate(to: language, type: "USES_LANGUAGE")
            app.relate(to: language, type: "USES_LANGUAGE", properties: ["count": dict[key]!])
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
    
    var supportedLanguages: [Application.Analyse.Language] = [.swift, .cpp, .java]
    var supportedLevel: Level = .applicationLevel
    var readme = "Finds out how often different types of file endings occur in the codebase."
}



class Language {
    var name: String
    
    init(name: String) {
        self.name = name
    }
    
    var nodeSet: Node?
}

extension Language: Neo4jObject {
    typealias ObjectType = Language
    static var nodeType = "Language"
    
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
