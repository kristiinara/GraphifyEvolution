//
//  DatabaseController.swift
//  
//
//  Created by Kristiina Rahkema on 01.10.2020.
//

import Foundation

import Theo
import PackStream
import Dispatch

class Node {
    var label: String
    var id: Int?
    var properties: [String:Any] = [:]
    
    init(label: String, properties: [String:Any]) {
        self.label = label
        self.properties = properties
    }
    
    var propertyString: String {
        var res = ""
        
        if self.properties.keys.count == 0 {
            res += "{}"
            return res
        }
        for key in self.properties.keys {
            if let value = self.properties[key] {
                if var value = value as? String {
                    value = value.replacingOccurrences(of: "\"", with: "\\\"")
                    value = value.replacingOccurrences(of: "\'", with: "\\\'")
                    value = value.replacingOccurrences(of: "\n", with: "\\\n")
                    
                    res += " \(key): '\(value)',"
                } else {
                    res += " \(key): \(value),"
                }
            }
    
        } // TODO: do we need to handle arrays?
        
        res = String(res.dropLast()) // remove last ","
        res = "{ \(res) }"
        return res
    }
}

class DatabaseController {
    let client: Neo4jClient?
    static var currentDatabase = DatabaseController() //TODO: should we do it another way?
    
    init() {
        self.client = Neo4jClient(
            hostname: "localhost",
            port: 7474,
            username: "neo4j",
            password: "1234"
        )
        
        /*
        let group = DispatchGroup()
            group.enter()
        
        self.client?.connect() { res in
            print("connect res: \(res)")
            group.leave()
        }
        group.wait()
        */
    }
    
    init(hostname: String = "localhost", port: Int = 7474, username: String = "neo4j", password: String = "1234") {
        self.client = Neo4jClient(
            hostname: hostname,
            port: port,
            username: username,
            password: password
        )
    }
    
    init(hostname: String = "localhost", port: Int = 7474, authorizationToken: String) {
        self.client = Neo4jClient(
            hostname: hostname,
            port: port,
            authorizationToken: authorizationToken
        )
    }
}

class Neo4jClient {
    let dataURL: URL
    let authorizationToken: String
    
    convenience init(hostname: String = "localhost", port: Int = 7474, username: String = "neo4j", password: String = "1234") {
        
        
        let token = Neo4jClient.generateAuthorizationToken(username: username, password: password)
        self.init(hostname: hostname, port: port, authorizationToken: token)
    }
    
    init(hostname: String = "localhost", port: Int = 7474, authorizationToken: String) {
        guard let url = URL(string: "http://\(hostname):\(port)/db/data/transaction/commit") else {
            fatalError("Incorrect url for hostname: \(hostname) and port \(port)")
        }
        self.dataURL = url
        self.authorizationToken = authorizationToken
    }
    
    static func generateAuthorizationToken(username: String, password: String) -> String {
        let token = Data("\(username):\(password)".utf8).base64EncodedString()
        return token
    }
    
    func createAndReturnNodeSync(node: Node) -> Node? {
        //TODO: return optinal, or retrun Result object --> read about Result objects!
        
        let transaction = "create (n:\(node.label) \(node.propertyString)) return id(n)"
        
        let group = DispatchGroup()
        group.enter()
        
        requestWithDefaultCompletition(transaction: transaction) { id in
            node.id = id
            group.leave()
        }
        group.wait()
        
        if node.id == nil {
            return nil
        }
        return node
    }
    
    func mergeNodeSync(node:Node) -> Node? {
        let transaction = "merge (n:\(node.label) \(node.propertyString)) return id(n)"
        
        let group = DispatchGroup()
        group.enter()
        
        requestWithDefaultCompletition(transaction: transaction) { id in
            node.id = id
            group.leave()
        }
        group.wait()
        
        if node.id == nil {
            return nil
        }
        return node
    }
    
    func updateNodeSync(node: Node) {
        //TODO: return result object?
        
        if let id = node.id {
            let transaction = "match (n:\(node.label)) where id(n)=\(id) set n += \(node.propertyString)"
            
            let group = DispatchGroup()
            group.enter()
            
            requestWithDefaultCompletition(transaction: transaction) { id in
                group.leave()
            }
            
            group.wait()
            //TODO: what happens if query fails?
            
        } else {
            let _ = createAndReturnNodeSync(node: node)
        }
    }
    
    func relateInParallel(node: Node, to: [Node], type: String) {
        let group = DispatchGroup()
        
        for nodeto in to {
            if let id = node.id, let toId = nodeto.id {
                let transaction = "match (a:\(node.label)), (c:\(nodeto.label)) where id(a) = \(id) and id(c) = \(toId) merge (a)-[r:\(type)]->(c) return id(r)"
                
                group.enter()
                
                requestWithDefaultCompletition(transaction: transaction) { id in
                    group.leave()
                }
                
            } else {
                print("could not relate node \(node.label) to \(nodeto.label)")
            }
        }

        group.wait()
    }
    
    func relateInParallel(node: Node, to: [Node], type: String, batchSize: Int) {
        if to.count <= batchSize {
            relateInParallel(node: node, to: to, type: type)
        } else {
            var start = 0
            var end = batchSize
            
            while start < to.count {
                if end >= to.count {
                    end = to.count - 1
                }
                
                let subset = Array(to[start...end])
                relateInParallel(node: node, to: subset, type: type)
                
                if start == to.count - 1 {
                    break
                }
                
                start = end
                end = end + batchSize
            }
        }
    }
    
    /*
    func updateInParallel(nodes: [Node]) {
        var notExistantNodes: [Node] = []
        
        let group = DispatchGroup()
        
        for node in nodes {
            if let id = node.id {
                let transaction = "match (n:\(node.label)) where id(n)=\(id) set n += \(node.propertyString)"
                
                group.enter()
                
                requestWithDefaultCompletition(transaction: transaction) { id in
                    group.leave()
                }
                
            } else {
                notExistantNodes.append(node)
            }
        }

        group.wait()
        
        for node in notExistantNodes {
            let _ = createAndReturnNodeSync(node: node)
        }
    }
 */
    
    func relateSync(node: Node, to: Node, relationship: Neo4jRelationship) {
        //TODO: return result object
        
        //print("Relate: \(node.properties["name"]) \(node.id) - \(to.properties["name"]) \(to.id)")
        
        
        if let id = node.id, let toId = to.id {
            let transaction = "match (a:\(node.label)), (c:\(to.label)) where id(a) = \(id) and id(c) = \(toId) merge (a)-[r:\(relationship.type)\(relationship.properitesString)]->(c) return id(r)"
            
            let group = DispatchGroup()
            group.enter()
            
            requestWithDefaultCompletition(transaction: transaction) { id in
               // node.id = id
                group.leave()
            }
            
            group.wait()
            //TODO: what happens if query fails?
            
        } else {
            print("could not relate")
        }
    }
    
    func runQuery(transaction: String) {
        let group = DispatchGroup()
        group.enter()
        
        requestNoReturn(transaction: transaction) { success in
            //print("Query completed, success? \(success)")
            group.leave()
        }
        
        group.wait()
    }
    
    private func requestNoReturn(transaction: String, completition: @escaping (Bool) -> Void ) {
        //print("requestNoReturn")
        let parameters = [
            "statements": [[
                "statement" : transaction
                ]]
        ]
        //print("running transaction: \(transaction)")
        
        requestWithParameters(parameters) { [unowned self] json in
//            guard let self = self else {
//                completition(nil)
//                return
//            }
            
            //print("request finished")
            let success = self.defaultErrorHandling(json: json)
            
//            print("----- JSON result (success? \(success)): -----")
//            print(json ?? "Empty response")
            
            if success {
                completition(true)
            } else {
                completition(false)
            }
        }
    }
    
    private func requestWithDefaultCompletition(transaction: String, completition: @escaping (Int?) -> Void) {
        //print("requestWithDefaultCompletition")
        let parameters = [
            "statements": [[
                "statement" : transaction
                ]]
        ]
        //print("running transaction: \(transaction)")
        
        requestWithParameters(parameters) { [unowned self] json in
//            guard let self = self else {
//                completition(nil)
//                return
//            }
            
            //print("request finished")
            let success = self.defaultErrorHandling(json: json)
            
//            print("----- JSON result (success? \(success)): -----")
//            print(json ?? "Empty response")
            
            if success {
                completition(self.getId(json))
            } else {
                completition(nil)
            }
        }
    }
    
    private func requestWithParameters(_ parameters: [String: Any], completition: @escaping ([String: Any]?) -> Void) {
        //print("requestWithParameters")
        //create the session object
        let session = URLSession.shared
        
        //now create the URLRequest object using the url object
        var request = URLRequest(url: dataURL)
        request.httpMethod = "POST" //set http method as POST
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted) // pass dictionary to nsdata object and set it as request body
        } catch let error {
            completition(["JsonError": error])
            print(error.localizedDescription)
            return
        }
        
        //try! print("REQUEST: \(JSONSerialization.jsonObject(with: request.httpBody!, options: .mutableContainers))")
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        request.addValue("Basic \(self.authorizationToken)", forHTTPHeaderField: "Authorization")
        
        //print("Starting request!")
        //create dataTask using the session object to send data to the server
        let task = session.dataTask(with: request as URLRequest, completionHandler: { [unowned self] data, response, error in
            
//            guard let self = self else {
//                completition(nil)
//                return
//            }
            
            //print("response: \(String(describing: response))")
            
            
            guard error == nil else {
                completition(["NetworkError" : error!])
                return
            }
            
            guard let data = data else {
                completition(nil)
                return
            }
            
            do {
                //create json object from data
                if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                    //print(json)
                    completition(json)
                }
            } catch let error {
                print(error.localizedDescription)
                completition(["JsonError": error])
            }
        })
        task.resume()
    }
    
    private func defaultErrorHandling(json: [String: Any]?) -> Bool {
        guard let json = json else {
            print("No results!")
            return false
        }
        
        if let jsonError = json["JsonError"] {
            print(jsonError)
            return false
        }
        
        if let networkError = json["NetworkError"] {
            print(networkError)
            return false
        }
        
        return true
    }
    
    private func getId(_ json: [String: Any]?) -> Int? {
        guard let json = json else { return nil }
        
        guard let results = json["results"] as? [[String:Any]] else {
            print("no results: \(json)")
            return nil
        }
        
        guard results.count > 0 else {
            print("Results length 0: \(json)")
            return nil
        }
        guard results[0]["errors"] == nil else {
            print("Resulted in errors: \(results[0]["errors"] as! [[String: Any]])")
            return nil
        }
        
        guard let data = results[0]["data"] as? [[String: Any]] else {
            print("no data: \(results[0])")
            return nil
        }
        
        guard data.count > 0 else {
            print("Data length 0")
            return nil
        }
        
        guard let row = data[0]["row"] as? [Any] else {
            print("no row: \(data)")
            return nil
        }
        
        guard row.count > 0 else {
            print("Row length 0")
            return nil
        }
        
        guard let id = row[0] as? Int else {
            print("No id: \(row)")
            return nil
        }
        
        return id
    }
    
}

class Neo4jRelationship {
    let node: Node
    let toNode: Node
    let type: String
    let properties: [String:Any]
    var id : Int?
    
    var properitesString: String {
        var propertiesString = "{"
        
        for key in properties.keys {
            let value = properties[key]!
            if let intValue = value as? Int {
                propertiesString += " \(key): \(intValue),"
            } else {
                var stringValue = "\(value)"
                stringValue = stringValue.replacingOccurrences(of: "\"", with: "\\\"")
                stringValue = stringValue.replacingOccurrences(of: "\'", with: "\\\'")
                stringValue = stringValue.replacingOccurrences(of: "\n", with: "\\\n")
                
                propertiesString += " \(key): '\(value)',"
            }
        }
        
        if properties.keys.count > 0 {
            propertiesString = String(propertiesString.dropLast())
        }
        
        propertiesString += " }"
        return propertiesString
    }
    
    init(node: Node, toNode: Node, type: String, properties: [String: Any] = [:]) {
        self.node = node
        self.toNode = toNode
        self.type = type
        self.properties = properties
    }
}
