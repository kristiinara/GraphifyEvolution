//
//  JavaSyntaxAnalyser.swift
//  GraphifySwift
//
//  Created by Kristiina Rahkema on 01.02.2021.
//

import Foundation

class JavaSyntaxAnalyser: SyntaxAnalyser {
    var constants: Kind = JavaKind()
    var directoryPath: String?
    
    func reset() {
        directoryPath = nil
    }
    
    func reset(with directoryPath: String) {
        self.directoryPath = directoryPath
    }
    
    func analyseFile(filePath: String, includePaths: [String]) -> [Class] {
        if let directoryPath = self.directoryPath {
            return runJavaCommand(path: filePath, directoryPath: directoryPath)
        }
        
        print("Directory path was nil - could not run java command")
        return []
    }
    
    func runJavaCommand(path: String, directoryPath: String) -> [Class] {
        let currentDirectory = FileManager.default.currentDirectoryPath
       // let res = Helper.shell(launchPath: "\(currentDirectory)/JavaAnalyser/gradlew", arguments: ["run", "--args='path'" , "--console=plain", "--quiet"])
        
        // Prerequisite: JavaAnalyser-uber.jar needs to be compiled first
        
        guard let directoryPath = self.directoryPath else {
            fatalError("Directorypath for JavaSyntaxAnalyser not specified")
        }
        
        let res = Helper.shell(launchPath: "/usr/bin/java", arguments: ["-jar", "\(currentDirectory)/JavaAnalyser/build/libs/JavaAnalyser-uber.jar", path, directoryPath])
        
        var json = res
        json = json.replacingOccurrences(of: "=", with: ": ")
        json = json.replacingOccurrences(of: "'", with: "\"")
        
        //json = "{\"key.endLine\": 9, \"key.startLine\": 9, \"key.kind\": \"source.lang.swift.ref.module\", \"key.name\": \"Foundation\", \"key.line\": 9, \"key.usr\": \"c:@M@Foundation\", \"key.column\": 8}"
        
        let decoder = JSONDecoder()
        
        var classes: [Class] = []

        do {
            
            //print("--------- json:")
            //print("json: \(json)")
            
            if let data = json.data(using: .utf8) {
              let myJson = try JSONSerialization.jsonObject(with: data,
                                                            options: JSONSerialization.ReadingOptions.mutableContainers) as Any

              if let items = myJson as? [[String: Any]] {
                for item in items {
                    //print("json item: \(item)")
                    if let entities = item["key.entities"] as? [[String:Any]] {
                        for entity in entities {
                            if let classInstance = parseClassFrom(json: entity, path: path) {
                                classInstance.path = path
                                
                                classes.append(classInstance)
                            }
                        }
                    }
                }
              }
            }
            
                    
        } catch {
            print("json failed")
            print("\(json)")
            fatalError("Cannot parse json from java analyser - \(error.localizedDescription)")
        }
        return classes
    }
}

struct JavaKind: Kind {
    let classKind = "ClassDeclaration"
    let structKind = "-----"
    let protocolKind = "InterfaceDeclaration"
    
    let staticVariableKind = "StaticVariableDeclaration"
    let classVariableKind = "----"
    let instanceVariableKind = "InstanceVariableDeclaration"
    
    let staticMethodKind = "StaticMethodDeclaration"
    let classMethodKind = "----"
    let instanceMethodKind = "InstanceMethodDeclaration"
    
    let callInstructionKind = "class com.github.javaparser.ast.expr.MethodCallExpr"
    let ifInstructionKind = "class com.github.javaparser.ast.stmt.IfStmt"
    let forInstructionKind = "class com.github.javaparser.ast.stmt.ForEachStmt"
    let whileInstructionKind = "class com.github.javaparser.ast.stmt.WhileStmt"
    let switchInstructionKind = "class com.github.javaparser.ast.stmt.SwitchStmt"
    let caseInstructionKind = "class com.github.javaparser.ast.stmt.CaseStmt"
    
    let nameKey = "key.name"
    let usrKey = "key.usr"
    let kindKey = "key.kind"
    let entitiesKey = "key.entities"
    let typeKey = "key.type"
    let startLineKey = "key.startLine"
    let endLineKey = "key.endLine"
    let pathKey = "key.path"
    let receiverUsrKey = "key.receiver_usr"
    let isDefinitionKey = "------"
    let argumentsKey = "key.parameters"
    let positionKey = "key.position"
    let modifiersKey = "key.modifiers"
    
    
    // TODO: add/use
    let parentsKey = "key.parents"
    let annotationsKey = "key.annotations"
    
    let annotationKind = "Annotation"
    let modifierKind = "Modifier"
    let classReferenceKind = "ClassReference"
    let enumKind = "EnumDeclaration"
}


