//
//  File.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

protocol Neo4jNode {
    var node: Node {get}
    var updatedNode: Node {get}
    var nodeType: String {get}
}

protocol Neo4jObject: Neo4jNode {
    associatedtype ObjectType
    
    //func fetchAll() -> [ObjectType]
    func save() -> Bool
    func relate(to: Neo4jNode, type: String) -> Bool
    func newNode() -> Node
    
    // Need to be implemented:
    //static func initFrom(node:Node) -> ObjectType
    static var nodeType: String {get}
    
    static func objectWith(properties: [String: String]) -> Int? //TODO: change it later to actual object and not just the id
}

extension Neo4jObject {
    
    var nodeType: String {
        return Self.nodeType
    }
    
    static func objectWith(properties: [String: String]) -> Int? {
        var returnID: Int? = nil
        
        if let client = DatabaseController.currentDatabase.client {
            returnID = client.requestNodeSync(label: Self.nodeType, properties: properties)
            
        }
        
        return returnID
    }
    
    func newNode() -> Node {
        //print("newNode \(Self.nodeType)")
        
        if let client = DatabaseController.currentDatabase.client {
            if let newNode = client.createAndReturnNodeSync(node: Node(label: Self.nodeType, properties: [:])) {
                return newNode
            }
            fatalError("Failing to insert new object \(Self.nodeType)")
        }
        
        fatalError("Failing to insert new object \(Self.nodeType)")
    }
    
    func newNodeWithMerge(node: Node) -> Node {
        
        if let client = DatabaseController.currentDatabase.client {
            if let newNode = client.mergeNodeSync(node: node) {
                return newNode
            }
            fatalError("Failing to insert new object \(Self.nodeType)")
        }
        
        fatalError("Failing to insert new object \(Self.nodeType)")
    }
    
    func save() -> Bool {
        print("save \(Self.nodeType) - \(self.node.id)")
        if let client = DatabaseController.currentDatabase.client {
            var res = client.updateNodeSync(node: self.updatedNode)
        }
        return false
    }
    
    func relate(_ relationship: Neo4jRelationship) -> Bool {
        //print("relate \(Self.nodeType) - \(relationship.type) - \(relationship.toNode.label)")
        if let client = DatabaseController.currentDatabase.client {
            client.relateSync(node: relationship.node, to: relationship.toNode, relationship: relationship) //TODO: fix: does not need that much info

            return true
        }
        
        return false
    }
    
    func relateInParallel(to: [Neo4jNode], type: String) -> Bool {
        var updatedNodes: [Node] = []
        
        for node in to {
            updatedNodes.append(node.updatedNode)
        }
        
        if let client = DatabaseController.currentDatabase.client {
            client.relateInParallel(node: self.updatedNode, to: updatedNodes, type: type, batchSize: 10)
            //client.relateInParallel(node: self.updatedNode, to: updatedNodes, type: type)
            return true
        } else {
            return false
        }
    }
    
    func relate(to: Neo4jNode, type: String) -> Bool {
        let relationship = Neo4jRelationship(node: self.updatedNode, toNode: to.updatedNode, type: type)
        
        return self.relate(relationship)
    }
    
    func relate(to: Neo4jNode, type: String, properties: [String:Any]) -> Bool {
        let relationship = Neo4jRelationship(node: self.updatedNode, toNode: to.updatedNode, type: type, properties: properties)
        
        return self.relate(relationship)
    }
    
}
