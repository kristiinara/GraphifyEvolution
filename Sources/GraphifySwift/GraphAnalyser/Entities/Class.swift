//
//  Class.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import Theo

enum ChangeType {
    case updated, created, undefined
}
    
class Class {
    enum ClassType: String {
        case classType, structureType, protocolType
    }
    
    var path: String
    var name: String
    var type: ClassType
    var code: String
    var usr: String
    var changeType: ChangeType = .undefined
    var version: Int = 1
    
    var methods: [Method]
    var variables: [Variable]
    
    var potentialMethods: [Method]?
    var potentialVariables: [Variable]?
    
    func saveMethods() {
        for method in methods {
            method.save()
            self.relate(to: method, type: "CLASS_OWNS_METHOD")
        }
    }
    
    func saveVariables() {
        for variable in variables {
            variable.save()
            self.relate(to: variable, type: "CLASS_OWNS_VARIABLE")
        }
    }
    
    //var children: [Class] = []
    var parent: Class?// {
//        didSet {
//            if let parent = self.parent {
//                parent.relate(to: self, type: "CLASS_CHANGED_TO")
//                self.version = parent.version + 1
//                self.save()
//            }
//        }
//    }
    
    func saveParent() {
        if let parent = self.parent {
            parent.relate(to: self, type: "CLASS_CHANGED_TO")
            self.version = parent.version + 1
            self.save()
        }
    }
    
    init() {
        self.name = ""
        self.path = ""
        self.type = .classType
        self.code = ""
        self.usr = ""
        self.methods = []
        self.variables = []
        //self.save()
    }
    
    init(name: String, path: String, type: ClassType, code: String, usr: String, methods: [Method], variables: [Variable]) {
        self.name = name
        self.path = path
        self.type = type
        self.code = code
        self.usr = usr
        self.methods = methods
        self.variables = variables
        //self.save()
        
        for method in methods {
            self.relate(to: method, type: "CLASS_OWNS_METHOD")
        }
        
        for variable in variables {
            self.relate(to: variable, type: "CLASS_OWNS_VARIABLE")
        }
    }
    
    var nodeSet: Node?
}

extension Class: Neo4jObject {
    typealias ObjectType = Class
    static var nodeType = "Class"
    
    /*
    static func initFrom(node: Node) -> Class {
        var classInstance = Class()
        
        if let name = node["name"] as? String {
            classInstance.name = name
        }
        
        if let path = node["path"] as? String {
            classInstance.path = path
        }
        
        if let usr = node["usr"]  as? String {
            classInstance.usr = usr
        }
        
        if let code = node["code"]  as? String {
            classInstance.code = code
        }
        
        if let version = node["version_number"] as? Int {
            classInstance.version = version
        }
        
        classInstance.nodeSet = node
        
        return classInstance
    }
 */
    
    var updatedNode: Node {
        let oldNode = self.node
        
        oldNode["name"] = self.name
        oldNode["path"] = self.path
        oldNode["usr"] = self.usr
               
        oldNode["code"] = self.code
        oldNode["version_number"] = self.version
        
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
