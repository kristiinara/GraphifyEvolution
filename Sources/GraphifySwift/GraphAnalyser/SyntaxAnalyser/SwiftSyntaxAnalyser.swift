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
        let target = "arm64-apple-ios13.7"
        let sdk = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS13.7.sdk"
        
        var arguments = ["-target", target, "-sdk", sdk ,"-j4"]
        arguments.append(contentsOf: includePaths)
               
        let request = Request.index(file: filePath, arguments: arguments)
               
        do {
            let result = try request.send()
            
            var classes: [Class] = []
            
            if let entities = result["key.entities"] as? [[String: SourceKitRepresentable]] {
                for entity in entities {
                    if let classInstance = self.parseClassFrom(json: entity, path: filePath) {
                        classInstance.path = filePath
                        classes.append(classInstance)
                        print("classInstance: \(classInstance.name) found")
                    } else {
                        print("no class instance in: \(entity)")
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
}
