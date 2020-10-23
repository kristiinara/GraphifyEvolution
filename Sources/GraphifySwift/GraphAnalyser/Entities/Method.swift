//
//  Method.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import Theo

class Method {
    enum MethodKind: String {
        case instanceMethod, classMethod, staticMethod
    }
        
    var name: String
    var kind: MethodKind
    var code: String
    var usr: String
    var type: String
    var changeType: ChangeType = .undefined
    var startLine: Int?
    var endLine: Int?
    var version = 1
        
    var instructions: [Instruction]? //Current idea: when instructions is nil, then object came from db, if not nil then read from structure analysis - used to calculate metrics
    
    var children: [Method] = []
    var parent: Method? {
        didSet {
            parent?.relate(to: self, type: "CHANGED_TO")
        }
    }
    
    init(name: String, type: String, kind: MethodKind, code: String, usr: String) {
        self.name = name
        self.kind = kind
        self.type = type
        self.code = code
        self.usr = usr
        //self.save()
    }
    
    var nodeSet: Node?
    
    var calledUsrs: [String] {
        var allUsrs: [String] = []
        
        if let instructions = instructions {
            for instruction in instructions {
                if let usr = instruction.calledUsr {
                    allUsrs.append(usr)
                }
            }
        }
        
        return allUsrs
    }
    
    var cyclomaticComplexity : Int {
        if let instructions = self.instructions {
            return instructions.reduce(1) { result, instruction in
                return result + instruction.complexity
            }
        }
        
        return 0
    }
    
    var maxNestingDepth: Int {
        if let instructions = self.instructions {
            let nestingDepths = instructions.map() {instruction in instruction.maxNestingDepth}
            return nestingDepths.max() ?? 0
        }
        
        return 0
    }
    
    var numberOfInstructions : Int? {
        if let instructions = self.instructions {
            return instructions.reduce(1) { (result, instruction) -> Int in
                if let subInstructions = instruction.instructions {
                    return result + subInstructions.count
                }
                return result + 0
            }
        }
        
        return nil
    }
    
}

extension Method: Neo4jObject {
    typealias ObjectType = Method
    static var nodeType = "Method"
    
    /*
    static func initFrom(node: Node) -> Class {

        return classInstance
    }
 */
    
    var updatedNode: Node {
        let oldNode = self.node
        
        oldNode["name"] = self.name
       // oldNode["kind"] = self.kind as! String
        oldNode["usr"] = self.usr
        oldNode["type"] = self.type
        oldNode["code"] = self.code
        oldNode["version_number"] = self.version
        oldNode["start_line"] = self.startLine
        oldNode["end_line"] = self.endLine
        oldNode["number_of_instructions"] = self.numberOfInstructions
        oldNode["cyclomatic_complexity"] = self.cyclomaticComplexity
        oldNode["max_nesting_depth"] = self.maxNestingDepth
        
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
