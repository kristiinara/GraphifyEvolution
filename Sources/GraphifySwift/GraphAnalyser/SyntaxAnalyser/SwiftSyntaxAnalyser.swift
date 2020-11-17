//
//  SwiftSyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import SourceKittenFramework

import IndexStoreDB

class SwiftSyntaxAnalyser: SyntaxAnalyser {
    let constants: Kind = SwiftKind()
    var filePaths: [String] = []
    
    func reset() {
        // TODO: do we need to reset something?
    }
    
    func tryingToAnalyse(path: String) {
        let dbPath: String = "/Applications/Xcode 2.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"
        let workspace = Workspace(storePath: "/Users/kristiina/Library/Developer/Xcode/DerivedData/SmallAppExample-dwkqgphxfuvqhxgbxrejrjcuzsgy/Index/DataStore", dbPath: dbPath)
        //workspace?.searchSymbol("ViewController")
        print(workspace?.allClasses(path: path))
        
        workspace?.searchSymbol("")
    }
    
    func analyseFile(filePath: String, includePaths: [String]) -> [Class] {
        
        //tryingToAnalyse(path: filePath)
        
        if let file = File(path: filePath) {
            do {
                let result = try Structure(file: file)
                   
                if let substructure = result.dictionary["key.substructure"] as? [[String:Any]] {
                    for element in substructure {
                        if let name = element["key.name"] {
                            print("found element: \(name)")
                            
                            if let children = element["key.substructure"] as? [[String:Any]] {
                                print("  children: \(children.count)")
                                for child in children {
                                    if let name = element["key.name"] {
                                        print("   \(name)")
                                    }
                                }
                            }
                        }
                        
                    }
                }
                
               // print(result)
            } catch {
                print("Syntax tree failed: \(error.localizedDescription)")
            }
        }
        
        /*
        let target = "arm64-apple-ios14.1"
        //let sdk = "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.1.sdk"
        let sdk = "/Applications/Xcode12.1.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.1.sd"
        
        var arguments = [filePath, "-target", target, "-sdk", sdk ,"-j4"]
        arguments.append(contentsOf: includePaths)
               
        let request = Request.index(file: filePath, arguments: arguments)
        print("Request: \(request)")
        
               
        do {
            let result = try request.send()
            
            var classes: [Class] = []
            
            if var entities = result["key.entities"] as? [[String: Any]] {
                entities = addLines(json: entities)
                
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
 */
        
        return []
    }
    
    func addLines(json: [[String:Any]]) -> [[String:Any]] {
        //print("add lines: \(json)")
        var res: [[String:Any]] = []

        for object in json {
            print("finding lines in: \(object)")
            print("keys: \(object.keys)")
            print("addLines for kind: \(object["key.kind"])")
            var newObject = object
            
            if let lineNumberString = object["key.line"] as? Int64 {
                print("key.line: \(lineNumberString)")
                
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
                
                print("no key.line \(object["key.line"])")
                res.append(object)
            }
        }
        
        print("added lines: \(res)")
        
        return res
    }
    
    func maxLine(json: [[String:Any]]) -> Int {
        var allLineNumbers: [Int] = [-1]
        
        for object in json {
            if let lineNumber = object["key.line"] as? Int {
                allLineNumbers.append(lineNumber)
                
                if let entities = object["key.entities"] as? [[String: Any]]{
                    allLineNumbers.append(maxLine(json: entities))
                }
            }
        }
        
        return allLineNumbers.max()!
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

class Workspace {
    static let libIndexStore = "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"
        
        let db: IndexStoreDB
        
        init?(storePath: String, dbPath: String) {
            do {
                let lib = try IndexStoreLibrary(dylibPath: Workspace.libIndexStore)
                self.db = try IndexStoreDB(
                    storePath: URL(fileURLWithPath: storePath).path,
                    databasePath: NSTemporaryDirectory() + "index_\(getpid())",
                    library: lib,
                    listenToUnitEvents: false)
                print("opened IndexStoreDB at \(dbPath) with store path \(storePath)")
            } catch {
                print("failed to open IndexStoreDB: \(error.localizedDescription)")
                return nil
            }
            
            db.pollForUnitChangesAndWait()
        }
    
    func allClasses(path: String) -> [String] {
        
       // let names = self.db.unitNamesContainingFile(path: path)
        
        let names = self.db.allSymbolNames()
        
        for name in names {
            self.searchSymbol(name)
        }
        
       // return names
        
        return []
    }
        
        func searchSymbol(_ symbol: String?) {
            guard var symbol = symbol else { return }
            
            if symbol.contains(".o") {
                let components = symbol.components(separatedBy: ".o")
                symbol = components.first!
            }
            
            //print("Searching symbol: \(symbol) ...")
            
            
            let symbolOccurences = db.canonicalOccurrences(ofName: symbol)
            if symbolOccurences.isEmpty {
                print("The symbol of \(symbol) not found")
            } else {
                symbolOccurences.forEach { (symbolOccurence) in
                    if symbolOccurence.location.isSystem == false {
                        print("Name:\t\t\(symbolOccurence.symbol.name)")
                        print("USR:\t\t\(symbolOccurence.symbol.usr)")
                        print("Location:\t\(symbolOccurence.location)")
                        print("Roles:\t\t\(symbolOccurence.roles)")

                        print("\n")
                        findReferences(symbolOccurence)
                    }
                }
            }
        }
        
        func findReferences(_ symbolOccurence: SymbolOccurrence) {
            db.occurrences(ofUSR: symbolOccurence.symbol.usr, roles: .reference).forEach {
                print("Reference Count: \($0.relations.count)")
                
                $0.relations.forEach { (symbolRelation) in
                    if let definition = db.occurrences(ofUSR: symbolRelation.symbol.usr, roles: .definition).first {
                        let path = URL.init(fileURLWithPath: definition.location.path)
                        var description = "\t\(symbolOccurence.symbol.name)'s "
                        description += "referenced in \(path.lastPathComponent) "
                        description += "by \(symbolRelation.symbol.kind):\(symbolRelation.symbol.name)"
                        description += ",line number:\(definition.location.line)"
                        print("\(description)\n")
                    }
                }
            }
        }
    }

