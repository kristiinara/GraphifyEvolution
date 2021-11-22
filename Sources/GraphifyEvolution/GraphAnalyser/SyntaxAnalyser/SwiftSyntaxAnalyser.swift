//
//  SwiftSyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import SourceKittenFramework

class SwiftSyntaxAnalyser: SyntaxAnalyser {
    let constants: Kind = SwiftKind()
    var filePaths: [String] = []
    
    func reset() {
        // TODO: do we need to reset something?
    }
    
    func analyseFile(filePath: String, includePaths: [String]) -> [Class] {
        let target = "arm64-apple-ios14.2"
        let sdk = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
        
        var arguments = ["-target", target, "-sdk", sdk ,"-j4"]
        arguments.append(contentsOf: includePaths)
               
        let request = Request.index(file: filePath, arguments: arguments)
               
        do {
            let result = try request.send()
            
            var classes: [Class] = []
            
            if var entities = result["key.entities"] as? [[String: Any]] {
                entities = addLines(json: entities)
                
                for entity in entities {
                    if let classInstance = self.parseClassFrom(json: entity, path: filePath) {
                        classInstance.path = filePath
                        classes.append(classInstance)
                        //print("classInstance: \(classInstance.name) found")
                    } else {
                        //print("no class instance in: \(entity)")
                    }
                }
            }
            
            return classes
        }
        catch {
            print("error while doing index request: \(error)")
        }
        
        return []
    }
    
    func addLines(json: [[String:Any]]) -> [[String:Any]] {
        //print("add lines: \(json)")
        var res: [[String:Any]] = []

        for object in json {
            //print("finding lines in: \(object)")
            //print("keys: \(object.keys)")
            //print("addLines for kind: \(object["key.kind"])")
            var newObject = object
            
            if let lineNumberString = object["key.line"] as? Int64 {
                //print("key.line: \(lineNumberString)")
                
                var lineNumber: Int = Int(lineNumberString)
                var maxNumber = lineNumber
            
                if let entities = object["key.entities"] as? [[String: Any]] {
                    maxNumber = maxLine(json: entities)
                    
                    if maxNumber == -1 {
                        maxNumber = lineNumber
                    }
                
                    let newEntities = addLines(json: entities)
                    newObject["key.entities"] = newEntities
                }
                
                newObject["key.startLine"] = lineNumber
                newObject["key.endLine"] = maxNumber
                
                res.append(newObject)
            } else {
                if let entities = object["key.entities"] as? [[String: Any]]{
                    let newEntities = addLines(json: entities)
                    newObject["key.entities"] = newEntities
                }
                
                //print("no key.line \(object["key.line"])")
                res.append(newObject)
            }
        }
        
       // print("added lines: \(res)")
        
        return res
    }
    
    func maxLine(json: [[String:Any]]) -> Int {
        var allLineNumbers: [Int] = [-1]
        
        for object in json {
            if let lineNumber = object["key.line"] as? Int64 {
                allLineNumbers.append(Int(lineNumber))
                
                if let entities = object["key.entities"] as? [[String: Any]]{
                    allLineNumbers.append(maxLine(json: entities))
                }
            }
        }
        
        if let max = allLineNumbers.max() {
            return max
        }
        
        return -1
    }
}

struct SwiftKind: Kind {
    let classKind = "source.lang.swift.decl.class"
    let structKind = "source.lang.swift.decl.struct"
    let protocolKind = "source.lang.swift.decl.protocol"
    
    let staticVariableKind = "source.lang.swift.decl.var.static"
    let classVariableKind = "source.lang.swift.decl.var.class"
    let instanceVariableKind = "source.lang.swift.decl.var.instance"
    
    let staticMethodKind = "source.lang.swift.decl.function.method.static"
    let classMethodKind = "source.lang.swift.decl.function.method.class"
    let instanceMethodKind = "source.lang.swift.decl.function.method.instance"
    let constructorKind = "" //?? "ConstructorDeclaration"
    
    let callInstructionKind = "source.lang.swift.expr.call"
    let ifInstructionKind = "source.lang.swift.stmt.if"
    let forInstructionKind = "source.lang.swift.stmt.for"
    let whileInstructionKind = "source.lang.swift.stmt.while"
    let switchInstructionKind = "source.lang.swift.stmt.switch"
    let caseInstructionKind = "source.lang.swift.stmt.case"
    
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
    let argumentsKey: String = "key.arguments" //TODO: check if correct
    let positionKey = "key.position" //TODO: check if correct
    let modifiersKey = "key.modifier" //TODO: check if correct
}
