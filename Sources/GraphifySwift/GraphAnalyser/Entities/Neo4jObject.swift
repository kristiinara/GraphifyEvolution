//
//  File.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import Theo

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
    //static func newInstance() -> ObjectType?
    func newNode() -> Node
    
    // Need to be implemented:
    //static func initFrom(node:Node) -> ObjectType
    static var nodeType: String {get}
}

extension Neo4jObject {
    
    var nodeType: String {
        return Self.nodeType
    }
    
    /*
     let node = client.createAndReturnNodeSync(node: Node(label: "", properties: [:])).get()
     
     client.updateNodeSync(node: node)
     
     client.relateSync(node: node, to: node, type: "Test")
     */
    
    func newNode() -> Node {
        print("newNode \(Self.nodeType)")
        if Self.nodeType == "App" {
            DatabaseController.currentDatabase.stop()
            DatabaseController.currentDatabase.start()
        }
        
        if let client = DatabaseController.currentDatabase.theo {
            do {
                let newNode = try client.createAndReturnNodeSync(node: Node(label: Self.nodeType, properties: [:])).get()
                return newNode
            } catch {
                fatalError("Failing to insert new object \(Self.nodeType) - \(error.localizedDescription)")
            }
        }
        
        fatalError("Failing to insert new object \(Self.nodeType)")
    }
    
    /*
    static func newInstance() -> ObjectType? {
        print("newInstance \(Self.nodeType)")
        if let client = DatabaseController.currentDatabase.theo {
            do {
                let newNode = try client.createAndReturnNodeSync(node: Node(label: Self.nodeType, properties: [:])).get()
                let newObject = Self.initFrom(node: newNode)
            } catch {
                fatalError("Failing to insert new object \(Self.nodeType) - \(error.localizedDescription)")
            }
        }
        return nil
    }
 */
    
    func save() -> Bool {
        print("save \(Self.nodeType)")
        if let client = DatabaseController.currentDatabase.theo {
            var res = client.updateNodeSync(node: self.updatedNode)
//            do {
//                try client.updateNodeSync(node: self.updatedNode)
//            } catch {
//                fatalError("Failing to save object \(Self.nodeType) - \(error.localizedDescription)")
//            }
        }
        return false
    }
    
    func relate(to: Neo4jNode, type: String) -> Bool {
        print("relate \(Self.nodeType) - \(type) - \(to.nodeType)")
        if let client = DatabaseController.currentDatabase.theo {
            var res = client.relateSync(node: self.node, to: to.node, type: type)
//            do {
//                try client.relateSync(node: self.node, to: to.node, type: type)
//            } catch {
//                fatalError("Failing to relate objects \(Self.nodeType) - \(type) - \(to.nodeType) -- \(error.localizedDescription)")
//            }
        }
        return false
    }
    
}
