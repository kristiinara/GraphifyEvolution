//
//  CPPSyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import SourceKittenFramework

class CPPSyntaxAnalyser: SyntaxAnalyser {
    let constants: Kind = CPPKind() // TODO: change this later, currently analyse.py enters swift like keys
    var result: String?
    var classes: [String:[Class]]?
    
    func reset() {
        result = nil
        classes = nil
    }
    
    func analyseFile(filePath: String, includePaths: [String]) -> [Class] {
        print("analyseFile \(filePath)")
        
        /*
        if !includePaths.contains(filePath) {
            print("Filepath \(filePath) not in includePaths: \(includePaths)")
            return []
        }
 */
        
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
            print("finished analysing json, found \(classes)")
            if let classesForFile = classes[filePath] {
                return classesForFile
            } else {
                var alternatePath = filePath
                if filePath.contains("/src/") {
                    alternatePath = alternatePath.replacingOccurrences(of: "/src/", with: "/include/")
                    alternatePath = alternatePath.replacingOccurrences(of: ".cpp", with: ".h")
                } else if filePath.contains("/include/") {
                    alternatePath = alternatePath.replacingOccurrences(of: "/include/", with: "/src/")
                    alternatePath = alternatePath.replacingOccurrences(of: ".h", with: ".cpp")
                }
                
                if let classesForFile = classes[alternatePath] {
                    return classesForFile
                }
                
                if filePath.hasSuffix("main.cpp") || filePath.contains("inpututils") || filePath.contains("functions") {
                    //ignore right now
                    //TODO: figure out if we should add as separate class
                    return []
                }
                
                print("no classes for filepath: \(filePath) or alternatePath: \(alternatePath), allClasses: \(classes)")
                //fatalError("no classes for filepath: \(filePath) or alternatePath: \(alternatePath), allClasses: \(classes)")
            }
        }
        return []
    }
    
    func runPythonCommand(path: String){
        let currentDirectory = FileManager.default.currentDirectoryPath
        print("run python: \(currentDirectory)/PythonCppAnalyser/analyse.py")
        
       // let res = Helper.shell(launchPath: "/usr/bin/python", arguments:
        //    ["\(currentDirectory)/PythonCppAnalyser/analyse.py", path])
        
        let res = Helper.shell(launchPath: "/bin/bash", arguments: ["-c", "\(currentDirectory)/CAnalyser/test \(path) -I\(path)/include -x c++ -I/usr/local/opt/llvm/bin/../include/c++/v1 -I/usr/local/Cellar/llvm/9.0.0_1/lib/clang/9.0.0/include -I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include -I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks -I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks/Kernel.framework/Headers/ -lclang -std=c++20"])
        
        var json = res
        json = json.replacingOccurrences(of: "\"\"", with: "\"")
        json = json.replacingOccurrences(of: "\"key.name\": \",\n", with: "\"key.name\": \"\",\n")
        json = json.replacingOccurrences(of: "\"key.usr\": \",\n", with: "\"key.usr\": \"\",\n")
        json = json.replacingOccurrences(of: "\"key.kind\": \",\n", with: "\"key.kind\": \"\",\n")
        
        let decoder = JSONDecoder()

        do {
            
            print("--------- json:")
            print("json: \(json)")
            
            
            if let data = json.data(using: .utf8) {
              let myJson = try JSONSerialization.jsonObject(with: data,
                                                            options: JSONSerialization.ReadingOptions.mutableContainers) as Any

              if let items = myJson as? [[String: Any]] {
                for item in items {
                    parseCppClassFrom(item: item, path: path)
                }
              }
            }
            
                    
        } catch {
            print("json failed")
            print("\(json)")
            fatalError("Cannot parse json from c++ python analyser - \(error.localizedDescription)")
        }
    }
    
    func parseCppClassFrom(item: [String: Any], path: String) {
        var subItems: [[String: Any]] = []
        
        if let kind = item[constants.kindKey] as? String {
            if kind == constants.classKind {
                let classInstance = parseClassFrom(json: item, path: path)
                addClass(classInstance: classInstance)
            } else {
                if let entities = item[constants.entitiesKey] as? [[String: Any]] {
                    for entity in entities {
                        if let subKind = entity[constants.kindKey] as? String {
                            if [constants.staticMethodKind, constants.classMethodKind,
                                       constants.instanceMethodKind, constants.classVariableKind,
                                       constants.staticVariableKind, constants.instanceVariableKind]
                                        .contains(subKind) {
                                subItems.append(entity)
                                
                                //classWithEntities(entities: entities, path: path)
                                //break
                                
                            } else {
                                parseCppClassFrom(item: entity, path: path)
                            }
                        } else {
                            parseCppClassFrom(item: entity, path: path)
                        }
                    }
                }
            }
        }
        
        if subItems.count > 0 {
            classWithEntities(entities: subItems, path: path)
        }
        
        print("json item: \(item)")
        
    }
    
    func classWithEntities(entities: [[String: Any]], path: String) {
        var methods: [Method] = []
        var variables: [Variable] = []
        
        var path = path
        
        for entity in entities {
            print("entity name: \(entity[constants.nameKey]), kind: \(entity[constants.kindKey])")
            if let kind = entity[constants.kindKey] as? String {
                if [constants.instanceMethodKind, constants.staticMethodKind, constants.classMethodKind].contains(kind) {
                    
                    if let method = parseMethodFrom(json: entity) {
                        methods.append(method)
                        print("parsed method: \(method.name), \(method.usr)")
                    } else {
                        print("could not parse method")
                        print("json: \(entity)")
                    }
                } else if [constants.instanceVariableKind, constants.staticVariableKind, constants.classVariableKind].contains(kind) {
                    
                    if let variable = parseVariableFrom(json: entity) {
                        variables.append(variable)
                        print("parsed variable: \(variable.name), \(variable.usr)")
                    } else {
                        print("could not parse variable")
                        print("json: \(entity)")
                    }
                }
                
            }
            
            if let existingPath = entity[constants.pathKey] as? String {
                path = existingPath
            }
        }
        
        let className = String(path.split(separator: "/").last!)
        let usr = path
        let type: Class.ClassType = .classType
        
        let classInstance = Class(name: className, path: path, type: type, code: "", usr: usr, methods: methods, variables: variables)
        addClass(classInstance: classInstance)
    }
    
    func addClass(classInstance: Class?) {
        if let classInstance = classInstance {
            var classes: [String: [Class]]
            
            if let existing = self.classes {
                classes = existing
            } else {
                classes = [:]
            }
            
            var classesForPath: [Class] = []
            
            if let existingClassesForPath = classes[classInstance.path] {
                classesForPath = existingClassesForPath
            }
            
            classesForPath.append(classInstance)
            classes[classInstance.path] = classesForPath
            
            self.classes = classes
        } else {
            print("No classes found");
        }
    }
}

struct CPPKind: Kind {
    let classKind = "ClassDecl"
    let structKind = "StructDecl"
    let protocolKind = "----"
    
    let staticVariableKind = "----" //TODO: check how we should destinguish these
    let classVariableKind = "----"
    let instanceVariableKind = "FieldDecl"
    
    let staticMethodKind = "FunctionDecl" // not completely correct, in reality we should add:
    // let functionKind = "FunctionDecl"
    let classMethodKind = "CXXConstructor"
    let instanceMethodKind = "CXXMethod"
    
    //TODO: add additional statements?
    let callInstructionKind = "CallExpr"
    let ifInstructionKind = "IfStmt"
    let forInstructionKind = "ForStmt"
    let whileInstructionKind = "WhileStmt"
    let switchInstructionKind = "SwitchStmt"
    let caseInstructionKind = "CaseStmt"
    
    let nameKey = "key.name"
    let usrKey = "key.usr"
    let kindKey = "key.kind"
    let entitiesKey = "key.entities"
    let typeKey = "key.type"
    let startLineKey = "key.startLine"
    let endLineKey = "key.endLine"
    let pathKey = "key.path"
    let receiverUsrKey = "key.receiver_usr"
    let isDefinitionKey = "key.isCursorDefinition"
    
    
    // TODO: add/use
    let modifiersKey = "key.modifiers"
    let parentsKey = "key.parents"
    let annotationsKey = "key.annotations"
    let parametersKey = "key.parameters"
    
    //let annotationKind = "Annotation"
    //let modifierKind = "Modifier"
    let classReferenceKind = "TypeRef"
    // NamespaceRef
    let enumKind = "EnumDecl"
}
