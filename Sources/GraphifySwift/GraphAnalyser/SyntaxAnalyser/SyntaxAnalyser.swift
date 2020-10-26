//
//  SyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 16.09.2020.
//

import Foundation
import SourceKittenFramework

protocol SyntaxAnalyser {
    func reset()
    func analyseFile(filePath: String, includePaths: [String]) -> [Class]
    
    func parseClassFrom(json: [String:Any]) -> Class?
    func parseMethodFrom(json: [String:Any]) -> Method?
    func parseInstructionFrom(json: [String: Any]) -> Instruction?
    func parseVariableFrom(json: [String:Any]) -> Variable?
    func getCodeForPath(path: String) -> String?
    
}

extension SyntaxAnalyser {
    func parseClassFrom(json: [String:Any]) -> Class? {
        if let name = json["key.name"] as? String,
            let usr = json["key.usr"] as? String {
            
            var path = json["key.path"] as? String
            
            var classType: Class.ClassType = .classType
            
            if let kind = json["key.kind"] as? String {
                if kind == "source.lang.swift.ref.class" {
                    classType = .classType
                } else if kind == "source.lang.swift.ref.struct" {
                    classType = .structureType
                } else if kind == "source.lang.swift.ref.protocol" {
                    classType = .protocolType
                }
            }
            
            var dataString = "--"
            if let path = path {
                if let codeFromFile = getCodeForPath(path: path) {
                    dataString = codeFromFile
                }
            } else {
                path = ""
            }
            
            var methods: [Method] = []
            var variables: [Variable] = []
            
            if let entities = json["key.entities"] as? [[String: Any]] {
                for entity in entities {
                    if let kind = entity["key.kind"] as? String {
                        if kind == "source.lang.swift.decl.function.method.class" ||
                            kind == "source.lang.swift.decl.function.method.instance" ||
                            kind == "source.lang.swift.decl.function.method.static" {
                            
                            if let method = parseMethodFrom(json: entity) {
                                methods.append(method)
                            }
                            
                        } else if kind == "source.lang.swift.decl.var.instance" ||
                            kind == "source.lang.swift.decl.var.class" ||
                            kind == "source.lang.swift.decl.var.static" {
                            
                            if let variable = parseVariableFrom(json: entity) {
                                variables.append(variable)
                            }
                            
                        }
                    }
                }
            }
            
            let classInstance = Class(name: name, path: path!, type: classType, code: dataString, usr: usr, methods: [], variables: [])
            
            if methods.count > 0 {
                classInstance.potentialMethods = methods
            }
            
            if variables.count > 0 {
                classInstance.potentialVariables = variables
            }
            
            return classInstance
        } else {
            
        }
        return nil
    }
    
    func parseMethodFrom(json: [String:Any]) -> Method? {
        if let name = json["key.name"] as? String,
            let usr = json["key.usr"] as? String,
            let kind = json["key.kind"] as? String {
            
            var methodKind: Method.MethodKind = .instanceMethod
            
            if kind == "source.lang.swift.decl.function.method.instance" {
                methodKind = .instanceMethod
            } else if kind == "source.lang.swift.decl.function.method.class" {
                methodKind = .classMethod
            } else if kind == "source.lang.swift.decl.function.method.static" {
                methodKind = .staticMethod
            }
            
            var methodType = "" //TODO: should we keep it empty if not defined?

            if let type = json["key.type"] as? String {
                methodType = type
            }
            
            var instructions: [Instruction] = []
            
            if let subEntities = json["key.entities"] as? [[String: Any]] {
                for subEntity in subEntities {
                    if let instruction = parseInstructionFrom(json: subEntity) {
                        instructions.append(instruction)
                    }
                }
            }
            
            //TODO: add code
            let method = Method(name: name, type: methodType, kind: methodKind, code: "", usr: usr)
            method.instructions = instructions
            
            if let startLine = json["key.startLine"] as? Int {
                method.startLine = startLine
            }
            
            if let endLine = json["key.endLine"] as? Int {
                method.endLine = endLine
            }
            
            //method.save()
            
            return method
        }
        return nil
    }
    
    func parseInstructionFrom(json: [String: Any]) -> Instruction? {
        var type: Instruction.InstructionType = .regularInstruction
        
        if let kind = json["key.kind"] as? String {
            if kind == "source.lang.swift.expr.call" {
                type = .regularInstruction
            } else if kind == "source.lang.swift.stmt.if" {
                type = .ifInstruction
            } else if kind == "source.lang.swift.stmt.for" {
                type = .forInstruction
            } else if kind == "source.lang.swift.stmt.while" {
                type = .whileInstruction
            } else if kind == "source.lang.swift.stmt.switch" {
                type = .switchInstruction
            } else if kind == "source.lang.swift.stmt.case" {
                type = .caseInstruction
            }
        }
        
        // TODO: get code
        let instruction = Instruction(type: type, code: "")
        
        if let usr = json["key.usr"] as? String {
            instruction.calledUsr = usr
        }
        
        if let startLine = json["key.startLine"] as? Int {
            instruction.startLine = startLine
        }
        
        if let endLine = json["key.endLine"] as? Int {
            instruction.endLine = endLine
        }
        
        var subInstructions: [Instruction] = []
        
        if let entities = json["key.entities"] as? [[String: Any]] {
            for entity in entities {
                if let subInstruction = parseInstructionFrom(json: entity) {
                    subInstructions.append(subInstruction)
                }
            }
        }
        instruction.instructions = subInstructions
        
        return instruction
    }
    
    func parseVariableFrom(json: [String:Any]) -> Variable? {
        if let name = json["key.name"] as? String,
            let usr = json["key.usr"] as? String,
            let kind = json["key.kind"] as? String {
            
            var variableKind: Variable.VariableKind = .instanceVariable
            
            if kind == "source.lang.swift.decl.var.instance" {
                variableKind = .instanceVariable
            } else if kind == "source.lang.swift.decl.var.class" {
                variableKind = .classVariable
            } else if kind == "source.lang.swift.decl.var.static" {
                variableKind = .staticVariable
            }
            
            var type = ""
            if let variableType = json["key.type"] as? String {
                type = variableType
            }
            
            //TODO: add code
            let variable = Variable(name: name, type: type, kind: variableKind, code: "", usr: usr)
            return variable
            
            if let startLine = json["key.startLine"] as? Int {
                variable.startLine = startLine
            }
            
            if let endLine = json["key.endLine"] as? Int {
                variable.endLine = endLine
            }
        }
        return nil
    }
    
    func getCodeForPath(path: String) -> String? {
        var dataString: String? = nil
        
        if let file = File(path: path)  {
            let fileContents = file.contents
            dataString = fileContents
        }
        
        return dataString
    }
}
