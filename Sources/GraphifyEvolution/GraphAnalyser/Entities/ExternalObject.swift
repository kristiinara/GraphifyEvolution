//
//  ExternalObject.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import Theo

class ExternalObject {
    var name: String?
    var usr: String //TODO: should we add something
    
    init(name: String, usr: String) {
        self.name = name
        self.usr = usr
    }
    
    init(usr: String) {
        self.usr = usr
    }
    
    var nodeSet: Node?
}

extension ExternalObject: Neo4jObject {
    typealias ObjectType = App
    static var nodeType = "External"
    
    var updatedNode: Node {
        let oldNode = self.node
        
        oldNode.properties["name"] = self.name
        oldNode.properties["usr"] = self.usr
        
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
