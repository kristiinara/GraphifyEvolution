//
//  SyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 16.09.2020.
//

import Foundation
import SourceKittenFramework

protocol SyntaxAnalyser {
    var constants: Kind { get }
    
    func reset()
    func reset(with directoryPath: String)
    func analyseFile(filePath: String, includePaths: [String]) -> [Class]
    
    func parseClassFrom(json: [String:Any], path: String) -> Class?
    func parseMethodFrom(json: [String:Any]) -> Method?
    func parseInstructionFrom(json: [String: Any]) -> Instruction?
    func parseVariableFrom(json: [String:Any]) -> Variable?
    func getCodeForPath(path: String) -> String?
    
}

protocol Kind {
    var classKind: String { get }
    var structKind: String { get }
    var protocolKind: String { get }
    
    var staticVariableKind: String { get }
    var classVariableKind: String { get }
    var instanceVariableKind: String { get }
    
    var staticMethodKind: String { get }
    var classMethodKind: String { get }
    var instanceMethodKind: String { get }
    
    var callInstructionKind: String { get }
    var ifInstructionKind: String { get }
    var forInstructionKind: String { get }
    var whileInstructionKind: String { get }
    var switchInstructionKind: String { get }
    var caseInstructionKind: String { get }
    
    var nameKey: String { get }
    var isDefinitionKey: String { get }
    var usrKey: String { get }
    var kindKey: String { get }
    var entitiesKey: String { get }
    var typeKey: String { get }
    var startLineKey: String { get }
    var endLineKey: String { get }
    var pathKey: String { get }
    var receiverUsrKey: String { get }
}

extension SyntaxAnalyser {
    func reset(with directoryPath: String) {
        reset()
    }
    
    func parseClassFrom(json: [String:Any], path: String) -> Class? {
        print("class from: \(json)")
        if let name = json[constants.nameKey] as? String,
            let usr = json[constants.usrKey] as? String {
            print("name: \(name), usr: \(usr)")
            
            var classType: Class.ClassType = .classType
            
            if let kind = json[constants.kindKey] as? String {
                print("kind: \(kind)")
                if kind == constants.classKind {
                    classType = .classType
                } else if kind == constants.structKind {
                    classType = .structureType
                } else if kind == constants.protocolKind {
                    classType = .protocolType
                } else {
                    return nil // not a class
                }
            }
            
            var dataString = "--"
            var path = path
            
            if let existingPath = json[constants.pathKey] as? String {
                path = existingPath
            }
            
//            if let codeFromFile = getCodeForPath(path: path) {
//                dataString = codeFromFile
//            }
            
            var methods: [Method] = []
            var variables: [Variable] = []
            
            if let entities = json[constants.entitiesKey] as? [[String: Any]] {
                for entity in entities {
                    if let kind = entity[constants.kindKey] as? String {
                        if kind == constants.classMethodKind ||
                            kind == constants.instanceMethodKind ||
                            kind == constants.staticMethodKind {
                            
                            if let method = parseMethodFrom(json: entity) {
                                methods.append(method)
                            }
                            
                        } else if kind == constants.instanceVariableKind ||
                            kind == constants.instanceVariableKind ||
                            kind == constants.staticVariableKind {
                            
                            if let variable = parseVariableFrom(json: entity) {
                                variables.append(variable)
                            }
                            
                        }
                    } else {
                        if let variable = tryParseVariableFrom(json: entity) {
                            variables.append(variable)
                        }
                    }
                }
            }
            
            let classInstance = Class(name: name, path: path, type: classType, code: dataString, usr: usr, methods: [], variables: [])
            
            if methods.count > 0 {
                classInstance.potentialMethods = methods
            }
            
            if variables.count > 0 {
                classInstance.potentialVariables = variables
            }
            
            if let def = json[constants.isDefinitionKey] {
                print("type of: \(type(of: def))")
            }
            
            if let isDefinition = json[constants.isDefinitionKey] as? NSNumber {
                print("cast was successful")
                if isDefinition == 1 {
                    classInstance.isDefinition = true
                } else {
                    classInstance.isDefinition = false
                }
            } else {
                print("cast not successful")
                classInstance.isDefinition = nil
            }
            
            return classInstance
        } else {
            print("no class found")
        }
        return nil
    }
    
    func parseMethodFrom(json: [String:Any]) -> Method? {
        if let name = json[constants.nameKey] as? String,
            let usr = json[constants.usrKey] as? String,
            let kind = json[constants.kindKey] as? String {
            //print("parse method: \(usr)")
            
            var methodKind: Method.MethodKind = .instanceMethod
            
            //TODO: specify if set, get or constructor!
            if kind == constants.instanceMethodKind {
                methodKind = .instanceMethod
            } else if kind == constants.classMethodKind {
                methodKind = .classMethod
            } else if kind == constants.staticMethodKind {
                methodKind = .staticMethod
            }
            
            var methodType = "" //TODO: should we keep it empty if not defined?

            if let type = json[constants.typeKey] as? String {
                methodType = type
            }
            
            var instructions: [Instruction] = []
            
            if let subEntities = json[constants.entitiesKey] as? [[String: Any]] {
                for subEntity in subEntities {
                    if let instruction = parseInstructionFrom(json: subEntity) {
                        instructions.append(instruction)
                    }
                }
            }
            
            //TODO: add code
            let method = Method(name: name, type: methodType, kind: methodKind, code: "", usr: usr)
            method.instructions = instructions
            
            if let startLine = json[constants.startLineKey] as? Int {
                method.startLine = startLine
            }
            
            if let endLine = json[constants.endLineKey] as? Int {
                method.endLine = endLine
            }
            
            if let isDefinition = json[constants.isDefinitionKey] as? Int {
                if isDefinition == 1 {
                    method.isDefinition = true
                } else {
                    method.isDefinition = false
                }
            } else {
                method.isDefinition = nil
            }
            
            //method.save()
            
            return method
        }
        return nil
    }
    
    func parseInstructionFrom(json: [String: Any]) -> Instruction? {
        var type: Instruction.InstructionType = .regularInstruction
        
        if let kind = json[constants.kindKey] as? String {
            if kind == constants.callInstructionKind {
                type = .regularInstruction
            } else if kind == constants.ifInstructionKind {
                type = .ifInstruction
            } else if kind == constants.forInstructionKind {
                type = .forInstruction
            } else if kind == constants.whileInstructionKind {
                type = .whileInstruction
            } else if kind == constants.switchInstructionKind {
                type = .switchInstruction
            } else if kind == constants.caseInstructionKind {
                type = .caseInstruction
            }
        }
        
        // TODO: get code
        let instruction = Instruction(type: type, code: "")
        
        if let usr = json[constants.usrKey] as? String {
            //print("instruction with usr: \(usr)")
            instruction.calledUsr = usr
        }
        
        if let receiverUsr = json[constants.receiverUsrKey] as? String {
            instruction.receiverUsr = receiverUsr
        }
        
        if let calledName = json[constants.nameKey] as? String {
            instruction.calledName = calledName
        }
        
        if let startLine = json[constants.startLineKey] as? Int {
            instruction.startLine = startLine
        }
        
        if let endLine = json[constants.endLineKey] as? Int {
            instruction.endLine = endLine
        }
        
        var subInstructions: [Instruction] = []
        
        if let entities = json[constants.entitiesKey] as? [[String: Any]] {
            for entity in entities {
                if let subInstruction = parseInstructionFrom(json: entity) {
                    subInstruction.parent = instruction
                    subInstructions.append(subInstruction)
                }
            }
        }
        instruction.instructions = subInstructions
        
        return instruction
    }
    
    // none found!
    func tryParseVariableFrom(json: [String:Any]) -> Variable? {
        if let usr = json[constants.usrKey] as? String,
           let entities = json[constants.entitiesKey] as? [[String: Any]] {
            for entity in entities {
                if let attribute = entity["key.attribute"] as? String {
                    if attribute == "source.decl.attribute.iboutlet" {
                        let variable = Variable(name: usr, type: "?", kind: .instanceVariable, code: "", usr: usr)
                        return variable
                    }
                }
            }
        }
        return nil
    }
    
    func parseVariableFrom(json: [String:Any]) -> Variable? {
        if let name = json[constants.nameKey] as? String,
            let usr = json[constants.usrKey] as? String,
            let kind = json[constants.kindKey] as? String {
            
            var variableKind: Variable.VariableKind = .instanceVariable
            
            if kind == constants.instanceVariableKind {
                variableKind = .instanceVariable
            } else if kind == constants.classVariableKind{
                variableKind = .classVariable
            } else if kind == constants.staticVariableKind {
                variableKind = .staticVariable
            }
            
            var type = ""
            if let variableType = json[constants.typeKey] as? String {
                type = variableType
            }
            
            //TODO: add code
            let variable = Variable(name: name, type: type, kind: variableKind, code: "", usr: usr)
            
            if let startLine = json[constants.startLineKey] as? Int {
                variable.startLine = startLine
            }
            
            if let endLine = json[constants.endLineKey] as? Int {
                variable.endLine = endLine
            }
            
            if let isDefinition = json[constants.isDefinitionKey] as? Int {
                if isDefinition == 1 {
                    variable.isDefinition = true
                } else {
                    variable.isDefinition = false
                }
            } else {
                variable.isDefinition = nil
            }
            
            return variable
        }
        return nil
    }
    
    func getCodeForPath(path: String) -> String? {
        var dataString: String? = nil
        
        //print("Reaing file: \(path)")
        if let file = File(path: path)  {
            let fileContents = file.contents
            dataString = fileContents
        }
        
        return dataString
    }
}
