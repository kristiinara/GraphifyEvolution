//
//  File.swift
//  
//
//  Created by Kristiina Rahkema on 11.04.2023.
//

import Foundation

class QueryAnalyser {
    
    func queryAll(type: SmellType) {
        let analyser = CodeSmellAnalyser()
        
        var classQuery = ""
        var methodQuery = ""
        
        for smell in analyser.queries {
            if smell.type == .classInstance {
                classQuery = "\(classQuery), c.\(smell.property) as \(smell.property)"
            } else {
                methodQuery = "\(methodQuery), m.\(smell.property) as \(smell.property)"
            }
        }
        
        classQuery = "MATCH (a:App)-[:APP_OWNS_CLASS]->(c:Class) return a.name as app_name, a.commit as commit, c.name as class_name \(classQuery)"
        
        methodQuery = "MATCH (a:App)-[:APP_OWNS_CLASS]->(c:Class)-[:CLASS_OWNS_METHOD]->(m:Method) return a.name as app_name, a.commit as commit, c.name as class_name, m.name as method_name \(methodQuery)"
        
        var transaction = ""
        if type == .classInstance {
            transaction = classQuery
        } else {
            transaction = methodQuery
        }
        
        let databaseController = DatabaseController.currentDatabase
        let res = databaseController.client?.runQueryWithResult(transaction: transaction)
        
        if let res = res {
            if let results = res["results"] as? [[String: Any]] {
                for result in results {
                    if let columns = result["columns"] as? [String] {
                       print(columns.joined(separator: ","))
                    }
                    
                    if let datas = result["data"] as? [[String: Any]] {
                        for data in datas {
                            if let row = data["row"] as? [Any] {
                                print(row.map( { "\($0)" }).joined(separator: ","))
                            }
                        }
                    }
                }
            }
        }
    }
    
    func getAll() {
        let analyser = CodeSmellAnalyser()
        
        var classSmells: [String] = []
        var methodSmells: [String] = []
        
        for smell in analyser.queries {
            if smell.type == .classInstance {
                classSmells.append(smell.property)
            } else {
                methodSmells.append(smell.property)
            }
        }
        
        print("Class level smells: \(classSmells)")
        print("Method level smells: \(methodSmells)")
    }
    
    
}
