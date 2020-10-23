//
//  DatabaseController.swift
//  
//
//  Created by Kristiina Rahkema on 01.10.2020.
//

import Foundation

import Theo
import PackStream

class DatabaseController {
    let theo: BoltClient?
    static var currentDatabase = DatabaseController() //TODO: should we do it another way?
    
    init() {
        do {
            self.theo = try BoltClient(
                hostname: "127.0.0.1",
                port: 7687,
                username: "neo4j",
                password: "1234",
                encrypted: false
            )
            
            print("Client created?")
        } catch {
            print("Cannot connect - \(error.localizedDescription)")
            self.theo = nil
        }
        
        self.theo?.connectSync()
    }

    /*
    func fetchObjectsWith(label: String, completition: @escaping (([Node]?) -> Void)) {
        let labels = [label]
        let properties: [String:PackProtocol] = [:
            //"firstName": "Niklas",
            //"age": 38
        ]

        print("Running fetch")
        
        //TODO: current limit is 1000 --> how should we handle this?
        if let client = self.theo {
            client.nodesWith(labels: labels, andProperties: properties, limit: 1000) { result in
                
                do {
                    var values = try result.get()
                    completition(values)
                } catch {
                    print("nodes with error: \(error.localizedDescription)")
                }
            }
        } else {
            print("No db client")
        }
        completition(nil)
    }
 */
   
    func fetchApplications() {
        let labels = ["App"]
        let properties: [String:PackProtocol] = [:
            //"firstName": "Niklas",
            //"age": 38
        ]

        print("Running fetch")
        
        if let client = self.theo {
            
        }
        
        if let client = self.theo {
            client.nodesWith(labels: labels, andProperties: properties, limit: 1000) { result in
                print("Got some result")
                
                do {
                    var values = try result.get()
                    
                    
                    try print("Found \(values.count ?? 0) nodes")
                    for value in values {
                        print("\(value.labels) \(value["name"])")
                    }
                } catch {
                    print("nodes with error: \(error.localizedDescription)")
                }
            }
        } else {
            print("No db client")
        }
    }
}

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
            do {
                try client.updateNodeSync(node: self.updatedNode)
            } catch {
                fatalError("Failing to save object \(Self.nodeType) - \(error.localizedDescription)")
            }
        }
        return false
    }
    
    func relate(to: Neo4jNode, type: String) -> Bool {
        print("relate \(Self.nodeType) - \(type) - \(to.nodeType)")
        if let client = DatabaseController.currentDatabase.theo {
            do {
                try client.relateSync(node: self.node, to: to.node, type: type)
            } catch {
                fatalError("Failing to relate objects \(Self.nodeType) - \(type) - \(to.nodeType) -- \(error.localizedDescription)")
            }
        }
        return false
    }
    
}
