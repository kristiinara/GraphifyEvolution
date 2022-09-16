//
//  Variable.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Theo

class Variable: Codable {
    enum VariableKind: String, Codable {
        case instanceVariable, classVariable, staticVariable
    }
        
    var name: String = ""
    var kind: VariableKind = .instanceVariable
    var type: String = ""
    var code: String = ""
    var usr: String = ""
    var version: Int = 0
    var changeType: ChangeType = .undefined
    var isDefinition: Bool?
    
    var startLine: Int?
    var endLine: Int?
    
    var parent: Variable?
    var altParent: Variable?
    
    var childrenIds: [Int] = []
    
    func saveParent() {
        if let parent = self.parent {
            if let id = self.node.id {
                if !parent.childrenIds.contains(id) && parent.node.id != id {
                    self.version = parent.version + 1
                    parent.relate(to: self, type: "CHANGED_TO")
                    parent.childrenIds.append(id)
                }
            }
        }
        self.save()
    }
    
    func saveAltParent() {
        if let altParent = self.altParent {
            if let id = self.node.id {
                if !altParent.childrenIds.contains(id) && altParent.node.id != id {
                    altParent.relate(to: self, type: "CHANGED_TO")
                    altParent.childrenIds.append(id)
                }
            }
        }
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
        oldNode.properties["kind"] = self.kind.rawValue
        oldNode.properties["usr"] = self.usr
        oldNode.properties["type"] = self.type
        oldNode.properties["code"] = self.code
        oldNode.properties["version_number"] = self.version
        oldNode.properties["start_line"] = self.startLine
        oldNode.properties["end_line"] = self.endLine
        oldNode.properties["is_definition"] = isDefinition
        
        
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
    
