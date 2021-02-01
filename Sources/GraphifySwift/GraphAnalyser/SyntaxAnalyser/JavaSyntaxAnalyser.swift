//
//  JavaSyntaxAnalyser.swift
//  GraphifySwift
//
//  Created by Kristiina Rahkema on 01.02.2021.
//

import Foundation

class JavaSyntaxAnalyser: SyntaxAnalyser {
    var constants: Kind = JavaKind()
    
    func reset() {
    }
    
    func analyseFile(filePath: String, includePaths: [String]) -> [Class] {
        return runJavaCommand(path: filePath)
    }
    
    func runJavaCommand(path: String) -> [Class] {
        let currentDirectory = FileManager.default.currentDirectoryPath
       // let res = Helper.shell(launchPath: "\(currentDirectory)/JavaAnalyser/gradlew", arguments: ["run", "--args='path'" , "--console=plain", "--quiet"])
        
        // Prerequisite: JavaAnalyser-uber.jar needs to be compiled first
        let res = Helper.shell(launchPath: "/usr/bin/java", arguments: ["-jar", "\(currentDirectory)/JavaAnalyser/build/libs/JavaAnalyser-uber.jar", path])
        
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
                            if let classInstance = parseClassFrom(json: entity, path: "") {
                                
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
 
    
    var parsedString: String = """
    [{'key.usr'='null', 'key.entities'=[{'key.usr'='JavaAnalyser', 'key.entities'=[], 'key.name'='JavaAnalyser', 'key.kind'='class com.github.javaparser.ast.PackageDeclaration'}, {'key.usr'='TestClass', 'key.entities'=[{'key.usr'='null', 'key.entities'=[], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.Modifier'}, {'key.usr'='null', 'key.entities'=[{'key.usr'='someVariable', 'key.entities'=[{'key.usr'='String', 'key.entities'=[], 'key.name'='String', 'key.kind'='class com.github.javaparser.ast.type.ClassOrInterfaceType'}, {'key.usr'='null', 'key.entities'=[], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.expr.StringLiteralExpr'}], 'key.name'='someVariable', 'key.kind'='class com.github.javaparser.ast.body.VariableDeclarator'}], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.body.FieldDeclaration'}, {'key.usr'='testMethod', 'key.entities'=[{'key.usr'='null', 'key.entities'=[], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.Modifier'}, {'key.usr'='null', 'key.entities'=[], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.type.VoidType'}, {'key.usr'='null', 'key.entities'=[{'key.usr'='null', 'key.entities'=[{'key.usr'='println', 'key.entities'=[{'key.usr'='out', 'key.entities'=[{'key.usr'='System', 'key.entities'=[], 'key.name'='System', 'key.kind'='class com.github.javaparser.ast.expr.NameExpr'}], 'key.name'='out', 'key.kind'='class com.github.javaparser.ast.expr.FieldAccessExpr'}, {'key.usr'='null', 'key.entities'=[{'key.usr'='null', 'key.entities'=[], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.expr.StringLiteralExpr'}, {'key.usr'='someVariable', 'key.entities'=[], 'key.name'='someVariable', 'key.kind'='class com.github.javaparser.ast.expr.NameExpr'}], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.expr.BinaryExpr'}], 'key.name'='println', 'key.kind'='class com.github.javaparser.ast.expr.MethodCallExpr'}], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.stmt.ExpressionStmt'}], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.stmt.BlockStmt'}], 'key.name'='testMethod', 'key.kind'='class com.github.javaparser.ast.body.MethodDeclaration'}], 'key.name'='TestClass', 'key.kind'='class com.github.javaparser.ast.body.ClassOrInterfaceDeclaration'}], 'key.name'='null', 'key.kind'='class com.github.javaparser.ast.CompilationUnit'}]
    """
}

struct JavaKind: Kind {
    let classKind = "class com.github.javaparser.ast.body.ClassOrInterfaceDeclaration"
    let structKind = "-----"
    let protocolKind = "class com.github.javaparser.ast.body.ClassOrInterfaceDeclaration"
    
    let staticVariableKind = "class com.github.javaparser.ast.body.VariableDeclarator"
    let classVariableKind = "class com.github.javaparser.ast.body.VariableDeclarator"
    let instanceVariableKind = "class com.github.javaparser.ast.body.VariableDeclarator"
    
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


