//
//  GraphifyAbstractSynstaxTree.swift
//  
//
//  Created by Kristiina Rahkema on 16.09.2020.
//

import Foundation
import Theo

class ExternalObject {
    var name: String
    var usr: String //TODO: should we add something
    
    init(name: String, usr: String) {
        self.name = name
        self.usr = usr
    }
}
    
class App {
    var name: String
    //var code: String
    var versionNumber: Int = 1
    
    var usr: String? // USR??
    var commit: String?
    var parentCommit: String?
    var alternateParentCommit: String?
    
    var classes: [Class]
    
    var children: [App] = []
    weak var parent: App? {
        didSet {
            if let parent = self.parent {
                parent.relate(to: self, type: "CHANGED_TO")
            }
        }
    }
    var alternateApp: App? {
        didSet {
            if let alternateApp = self.alternateApp {
                alternateApp.relate(to: self, type: "CHANGED_TO")
            }
        }
    }
    
    init(name: String, classes: [Class]) {
        self.name = name
        self.classes = classes
        
        //self.save()
        for classInstance in classes {
            self.relate(to: classInstance, type: "APP_OWNS_CLASS")
        }
    }
    
    var nodeSet: Node?
}

extension App: Neo4jObject {
    typealias ObjectType = App
    static var nodeType = "App"
    
    /*
    static func initFrom(node: Node) -> App {
        var app = App(name: "", classes: [])
        
        if let name = node["name"] as? String {
            app.name = name
        }
        
        if let usr = node["usr"]  as? String {
            app.usr = usr
        }
        
        if let versionNumber = node["version_number"] as? Int {
            app.versionNumber = versionNumber
        }
        
        app.nodeSet = node
        
        return app
    }
 */
    
    var updatedNode: Node {
        let oldNode = self.node
        
        oldNode["name"] = self.name
        oldNode["usr"] = self.usr
        oldNode["version_number"] = self.versionNumber
        oldNode["commit"] = self.commit
        oldNode["parent_commit"] = self.parentCommit
        oldNode["alternate_parent_commit"] = self.alternateParentCommit
        
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
            self.relate(to: method, type: "CLASS_OWNS_METHOD")
        }
    }
    
    func saveVariables() {
        for variable in variables {
            self.relate(to: variable, type: "CLASS_OWNS_VARIABLE")
        }
    }
    
    var children: [Class] = []
    weak var parent: Class? {
        didSet {
            if let parent = self.parent {
                parent.relate(to: self, type: "CLASS_CHANGED_TO")
                self.version = parent.version + 1
                self.save()
            }
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
    
class Variable {
    enum VariableKind: String {
        case instanceVariable, classVariable, staticVariable
    }
        
    var name: String
    var kind: VariableKind
    var type: String
    var code: String
    var usr: String
    var version: Int = 0
    var changeType: ChangeType = .undefined
    
    var startLine: Int?
    var endLine: Int?
    
    weak var parent: Variable?
    var children: [Variable] = []
    
    init(name: String, type: String, kind: VariableKind, code: String, usr: String) {
        self.name = name
        self.type = type
        self.kind = kind
        self.code = code
        self.usr = usr
        //self.save()
    }
    
    var nodeSet: Node?
}

extension Variable: Neo4jObject {
    typealias ObjectType = Variable
    static var nodeType = "Variable"
    
    /*
    static func initFrom(node: Node) -> Class {

        return classInstance
    }
 */
    
    var updatedNode: Node {
        let oldNode = self.node
        
        oldNode["name"] = self.name
        //oldNode["kind"] = self.kind as! String
        oldNode["usr"] = self.usr
        oldNode["type"] = self.type
        oldNode["code"] = self.code
        oldNode["version_number"] = self.version
        oldNode["start_line"] = self.startLine
        oldNode["end_line"] = self.endLine
        
        
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
    

//TODO: how should we handle instructions? Enter the into the db? Use them to clculate metrics and save metrics?
class Instruction {
    enum InstructionType {
        case whileInstruction, forInstruction, ifInstruction, switchInstruction, caseInstruction, regularInstruction //TODO: regular instruction??
    }
    
    var instructions: [Instruction]?
        
    var type: InstructionType
    var code: String
    var startLine: Int?
    var endLine: Int?
    
    var calledUsr: String? //TODO: check if we need something else here!
    
    init(type: InstructionType, code: String) {
        self.type = type
        self.code = code
    }
    
    var complexity: Int {
        if let instructions = self.instructions {
            return instructions.reduce(0) { (result, instruction) -> Int in
                if instruction.type == .whileInstruction || instruction.type == .forInstruction || instruction.type == .caseInstruction || instruction.type == .switchInstruction || instruction.type == .ifInstruction {
                    return result + 1 + instruction.complexity
                }
                
                return result + instruction.complexity
            }
        }
        return 0
    }
    
    var maxNestingDepth: Int {
        var maxDepth = 0
        
        if let instructions = self.instructions {
            let nestingDepths = instructions.map() {instruction in instruction.maxNestingDepth}
            maxDepth = nestingDepths.max() ?? 0
        }
        
        if self.type != .regularInstruction {
            maxDepth += 1
        }
        
        return maxDepth
    }
    
    var chainedMessageCalls: [[Instruction]] {
        var calls: [[Instruction]] = []
        
        if let instructions = self.instructions {
            for instruction in instructions {
                var chainedCalls = instruction.chainedMessageCalls
                
                if instruction.type == .regularInstruction {
                    if chainedCalls.count > 0 {
                        chainedCalls = chainedCalls.map() { subCalls in
                            var res = [instruction]
                            res.append(contentsOf: subCalls)
                            return res
                        }
                    } else {
                        chainedCalls.append([instruction])
                    }
                }
                calls.append(contentsOf: chainedCalls)
            }
        }
        
        return calls
    }
    
    var maxNumberOfChanedMessageCalls: Int {
        let lengthOfMessageCalls = self.chainedMessageCalls.map() { chain in
            return chain.count
        }
        
        return lengthOfMessageCalls.max() ?? 0
    }
}

