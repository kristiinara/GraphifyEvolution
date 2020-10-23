//
//  CPPSyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import SourceKittenFramework

class CPPSyntaxAnalyser: SyntaxAnalyser {
    var result: String?
    var classes: [String:[Class]]?
    
    func reset() {
        result = nil
        classes = nil
    }
    
    func analyseFile(filePath: String, includePaths: [String]) -> [Class] {
        print("analyseFile \(filePath)")
        
        if classes == nil {
            var directoryPath: String? = nil
            if filePath.contains("/src/") {
                directoryPath = String(filePath.components(separatedBy: "/src/")[0])
            }
            
            if filePath.contains("/include/") {
                directoryPath = String(filePath.components(separatedBy: "/include/")[0])
            }
            
            if let directoryPath = directoryPath {
                runPythonCommand(path: "\(directoryPath)/")
            }
        }
        
        if let classes = classes {
            if let classesForFile = classes[filePath] {
                return classesForFile
            }
        }
        return []
    }
    
    func runPythonCommand(path: String){
        let currentDirectory = FileManager.default.currentDirectoryPath
        print("run python: \(currentDirectory)/PythonCppAnalyser/analyse.py")
        
        let res = Helper.shell(launchPath: "/usr/bin/python", arguments:
            ["\(currentDirectory)/PythonCppAnalyser/analyse.py", path])
        var json = res
        
        let decoder = JSONDecoder()

        do {
            
            print("--------- json:")
            print("json: \(json)")
            
            if let data = json.data(using: .utf8) {
              let myJson = try JSONSerialization.jsonObject(with: data,
                                                            options: JSONSerialization.ReadingOptions.mutableContainers) as Any

              if let items = myJson as? [[String: Any]] {
                for item in items {
                    print("json item: \(item)")
                    if let classInstance = parseClassFrom(json: item) {
                        if self.classes == nil {
                            self.classes = [:]
                        }
                        
                        var classesForPath: [Class] = []
                        
                        if let existingClassesForPath = self.classes![classInstance.path] {
                            classesForPath = existingClassesForPath
                        }
                        
                        classesForPath.append(classInstance)
                        self.classes![classInstance.path] = classesForPath
                    }
                }
              }
            }
            
                    
        } catch {
            print("json failed")
            print("\(json)")
            fatalError("Cannot parse json from c++ python analyser - \(error.localizedDescription)")
        }
    }
    
    func parseClassFrom(json: [String:Any]) -> Class? {
        if let name = json["key.name"] as? String,
            let path = json["key.path"] as? String,
            let usr = json["key.usr"] as? String {
            
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
            if let codeFromFile = getCodeForPath(path: path) {
                dataString = codeFromFile
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
            
            let classInstance = Class(name: name, path: path, type: classType, code: dataString, usr: usr, methods: [], variables: [])
            
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
    
/*
     let kind = structure["key.kind"] as! String
     let name = structure["key.name"] as! String
     let usr = structure["key.usr"] as? String
     let line = structure["key.line"] as? Int
     let column = structure["key.column"] as? Int
     
     var startLine = structure["key.startLine"] as? Int
     var endLine = structure["key.endLine"] as? Int
     
     if startLine == nil && endLine == nil {
         startLine = findMinLine(structure: structure)
         endLine = findMaxLine(structure: structure)
     }
     
     var relatedClasses: [(name: String, usr: String?)] = []
     var relatedStructures: [(name: String, usr: String?)] = []
     
     if let related = structure["key.related"] as? [[String: Any]] {
         for relatedInstence in related {
             let kind = relatedInstence["key.kind"] as? String
             let name = relatedInstence["key.name"] as? String
             let usr = relatedInstence["key.usr"] as? String
             
             if kind == "source.lang.swift.ref.class" {
                 if let name = name {
                     relatedClasses.append((name: name, usr: usr))
                 }
             } else if kind == "source.lang.swift.ref.struct" {
                 if let name = name {
                     relatedStructures.append((name: name, usr: usr))
                 }
             } else if kind == "source.lang.swift.ref.protocol" {
                 if let name = name {
                     relatedClasses.append((name: name, usr: usr))
                 }
             }
         }
     }
     */
    
    /*
    func getClassesFrom(objects: [[String: Any]]) {
        var allObjects : [FirstLevel] = [] // Use class instead of FirstLevel!
        var files: [String] = []
        
        for subStructure in objects {
            print("subStrcture: \(subStructure["key.name"]) \(subStructure["key.kind"])")
            print(subStructure.keys)
            var dataString = ""
            
            if let path = subStructure["key.path"] as? String {
                if let file = File(path: path)  {
                    files.append(path)
                    
                    let fileContents = file.contents
                    dataString = fileContents
                }
            }
            
            //TODO: implement this (both todos as 1 function!)
            let objects = analyseResult(result: ["key.entities": [subStructure]], dataString: dataString)
            
            if let path = subStructure["key.path"] as? String {
                for object in objects {
                    object.path = path
                    
                    //TODO: implement this
                    addStructureCpp(object: object, structure: ["key.entities": [subStructure]])
                }
            }
            
            allObjects.append(contentsOf: objects)
        }
    }
 */
    
}
