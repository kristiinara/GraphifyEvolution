//
//  Argument.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import Theo

class Parameter {
    var name: String
    var type: String
    var code: String
    var usr: String?
    var typeUsr: String?
    var position: Int?
    
    /*
    var startLine: Int?
    var endLine: Int?
    
    var parent: Argument?
    var altParent: Argument?
 */
    
    init(name: String, type: String, code: String) {
        self.name = name
        self.type = type
        self.code = code
        //self.save()
    }
    
    var nodeSet: Node?
}

/*
 Parameter is different from other entities as an object with the same value can be shared by multiple methods
 */
extension Parameter: Neo4jObject {
    typealias ObjectType = Parameter
    static var nodeType = "Parameter"

    var properties: [String: Any] {
        var properties: [String: Any]
        
        if let node = self.nodeSet {
            properties = node.properties
        } else {
            properties = [:]
        }
        
        properties["name"] = self.name
        properties["usr"] = self.usr
        properties["type"] = self.type
        properties["code"] = self.code
        properties["type_usr"] = self.typeUsr
        properties["position"] = self.position
        
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
    
