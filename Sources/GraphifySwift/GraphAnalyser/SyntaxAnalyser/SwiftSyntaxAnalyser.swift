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
               
        do {
            let result = try request.send()
            
            var classes: [Class] = []
            
            if let entities = result["key.entities"] as? [[String: SourceKitRepresentable]] {
                for entity in entities {
                    if let classInstance = self.parseClassFrom(json: entity) {
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
