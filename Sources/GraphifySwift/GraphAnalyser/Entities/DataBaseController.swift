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
    
    func start() {
        self.theo?.connectSync()
        //self.theo?.resetSync()
    }
    
    func stop() {
        self.theo?.disconnect()
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
