//
//  Variable.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import Theo

class Variable {
    enum VariableKind: String {
        case instanceVariable, classVariable, staticVariable
    }
        
    var name: String
    var kind: VariableKind
    var type: String
    var code: String
    var usr: String
    var version: Int = 0
    var changeType: ChangeType = .undefined
    
    var startLine: Int?
    var endLine: Int?
    
    var parent: Variable?
    var altParent: Variable?
    
    func saveParent() {
        parent?.relate(to: self, type: "CHANGED_TO")
        
        if let parent = self.parent {
            self.version = parent.version + 1
        }
        self.save()
    }
    
    func saveAltParent() {
        altParent?.relate(to: self, type: "CHANGED_TO")
    }
    
    init(name: String, type: String, kind: VariableKind, code: String, usr: String) {
        self.name = name
        self.type = type
        self.kind = kind
        self.code = code
        self.usr = usr
        //self.save()
    }
    
    var nodeSet: Node?
}

extension Variable: Neo4jObject {
    typealias ObjectType = Variable
    static var nodeType = "Variable"
    
    /*
    static func initFrom(node: Node) -> Class {

        return classInstance
    }
 */
    
    var updatedNode: Node {
        let oldNode = self.node
        
        oldNode.properties["name"] = self.name
        //oldNode["kind"] = self.kind as! String
        oldNode.properties["usr"] = self.usr
        oldNode.properties["type"] = self.type
        oldNode.properties["code"] = self.code
        oldNode.properties["version_number"] = self.version
        oldNode.properties["start_line"] = self.startLine
        oldNode.properties["end_line"] = self.endLine
        
        
        self.nodeSet = oldNode
        
        return oldNode
    }
    
    var node: Node {
        if nodeSet == nil {
            nodeSet = self.newNode()
        }
        
        return nodeSet!
    }
}
    
