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
    
    var childrenIds: [Int] = []
    var parent: Method?
    var altParent: Method?
    
    func saveParent() {
        if let parent = self.parent {
            self.version = parent.version + 1
            
            if let id = self.node.id {
                if !parent.childrenIds.contains(id) && parent.node.id != id  {
                    parent.relate(to: self, type: "CHANGED_TO")
                    parent.childrenIds.append(id)
                }
            }
        }
        self.save()
    }
    
    func saveAltParent() {
        if let altParent = self.altParent {
            if let id = self.node.id {
                if !altParent.childrenIds.contains(id) && altParent.node.id != id  {
                    altParent.relate(to: self, type: "CHANGED_TO")
                    altParent.childrenIds.append(id)
                }
            }
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
        print("CalledUsrs for \(self.usr)")
        
        if let instructions = instructions {
            print("Number of instructions: \(instructions.count)")
            for instruction in instructions {
                allUsrs.append(contentsOf: instruction.calledUsrs)
            }
        } else {
            print("no instructions")
        }
        print("allUsrs: \(allUsrs)")
        
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
        
        oldNode.properties["name"] = self.name
        oldNode.properties["kind"] = self.kind.rawValue
        oldNode.properties["usr"] = self.usr
        oldNode.properties["type"] = self.type
        oldNode.properties["code"] = self.code
        oldNode.properties["version_number"] = self.version
        oldNode.properties["start_line"] = self.startLine
        oldNode.properties["end_line"] = self.endLine
        oldNode.properties["number_of_instructions"] = self.numberOfInstructions
        oldNode.properties["cyclomatic_complexity"] = self.cyclomaticComplexity
        oldNode.properties["max_nesting_depth"] = self.maxNestingDepth
        
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
