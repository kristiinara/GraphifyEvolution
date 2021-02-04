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
    
    func analyseFile(filePath: String, includePaths: [String]) -> [Class] {
        if directoryPath == nil {
            if filePath.contains("/src/") {
                directoryPath = String(filePath.components(separatedBy: "/src/")[0]) + "/src/"
            }
        }
        
        if directoryPath != nil {
            print("Running java command, directory path: \(directoryPath)")
            return runJavaCommand(path: filePath)
        }
        
        print("Directory path was nil - could not run java command")
        return []
    }
    
    func runJavaCommand(path: String) -> [Class] {
        let currentDirectory = FileManager.default.currentDirectoryPath
       // let res = Helper.shell(launchPath: "\(currentDirectory)/JavaAnalyser/gradlew", arguments: ["run", "--args='path'" , "--console=plain", "--quiet"])
        
        // Prerequisite: JavaAnalyser-uber.jar needs to be compiled first
        let res = Helper.shell(launchPath: "/usr/bin/java", arguments: ["-jar", "\(currentDirectory)/JavaAnalyser/build/libs/JavaAnalyser-uber.jar", path, directoryPath!])
        
        var json = res
        json = json.replacingOccurrences(of: "=", with: ": ")
        json = json.replacingOccurrences(of: "'", with: "\"")
        
        //json = "{\"key.endLine\": 9, \"key.startLine\": 9, \"key.kind\": \"source.lang.swift.ref.module\", \"key.name\": \"Foundation\", \"key.line\": 9, \"key.usr\": \"c:@M@Foundation\", \"key.column\": 8}"
        
        let decoder = JSONDecoder()
        
        var classes: [Class] = []

        do {
            
            print("--------- json:")
            print("json: \(json)")
            
            if let data = json.data(using: .utf8) {
              let myJson = try JSONSerialization.jsonObject(with: data,
                                                            options: JSONSerialization.ReadingOptions.mutableContainers) as Any

              if let items = myJson as? [[String: Any]] {
                for item in items {
                    print("json item: \(item)")
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
    let classKind = "class com.github.javaparser.ast.body.ClassOrInterfaceDeclaration"
    let structKind = "-----"
    let protocolKind = "class com.github.javaparser.ast.body.ClassOrInterfaceDeclaration"
    
    let staticVariableKind = "class com.github.javaparser.ast.body.FieldDeclaration"
    let classVariableKind = "class com.github.javaparser.ast.body.FieldDeclaration"
    let instanceVariableKind = "class com.github.javaparser.ast.body.FieldDeclaration"
    
    let staticMethodKind = "class com.github.javaparser.ast.body.MethodDeclaration"
    let classMethodKind = "class com.github.javaparser.ast.body.MethodDeclaration"
    let instanceMethodKind = "class com.github.javaparser.ast.body.MethodDeclaration"
    
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
}


