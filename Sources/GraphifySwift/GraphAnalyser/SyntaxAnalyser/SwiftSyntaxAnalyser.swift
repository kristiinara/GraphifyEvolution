//
//  SwiftSyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import SourceKittenFramework

class SwiftSyntaxAnalyser: SyntaxAnalyser {
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
        //print("---- request: ----")
        //print("\(request)")
               
        do {
            let result = try request.send()
            //print(result)
            /*
            for key in result.keys {
                //print("key: \(key)")
                if let subresult = result[key] as? [[String: SourceKitRepresentable]] {
                    for value in subresult {
//                        for subKey in value.keys {
//                            //print("subkey: \(subKey)")
//
//                        }
                        if let name = value["key.name"] as? String {
                            if let kind = value["key.kind"] as? String {
                                if kind == "source.lang.swift.decl.class" {
                                    print(name)
                                }
                            }
                        }
                    }
                }
            }
            */
            // TODO: figure out if we can somehow use the dependencies
//            if let dependencies = result["key.dependencies"] as? [[String: SourceKitRepresentable]] {
//
//            }
            
            var classes: [Class] = []
            
            if let entities = result["key.entities"] as? [[String: SourceKitRepresentable]] {
                for entity in entities {
                    if let name = entity["key.name"] as? String,
                        let kind = entity["key.kind"] as? String,
                        let usr = entity["key.usr"] as? String {
                        //TODO: figure out what do do if we have multiple classes
                        if kind == "source.lang.swift.decl.protocol" {
                            print("protocol: \(name)")
                            let newClass = Class(name: name, path: filePath, type: .protocolType, code: "", usr: usr, methods: [], variables: [])
                            classes.append(newClass)
                        } else if kind == "source.lang.swift.decl.class" {
                            print("class: \(name)")
                            let newClass = Class(name: name, path: filePath, type: .classType, code: "", usr: usr, methods: [], variables: [])
                            classes.append(newClass)
                        } else if kind == "source.lang.swift.decl.struct" {
                            print("struct: \(name)")
                            let newClass = Class(name: name, path: filePath, type: .structureType, code: "", usr: usr, methods: [], variables: [])
                            classes.append(newClass)
                        }
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
