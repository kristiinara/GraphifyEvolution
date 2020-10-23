//
//  Instruction.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation

//TODO: how should we handle instructions? Enter the into the db? Use them to clculate metrics and save metrics?
class Instruction {
    enum InstructionType {
        case whileInstruction, forInstruction, ifInstruction, switchInstruction, caseInstruction, regularInstruction //TODO: regular instruction??
    }
    
    var instructions: [Instruction]?
        
    var type: InstructionType
    var code: String
    var startLine: Int?
    var endLine: Int?
    
    var calledUsr: String? //TODO: check if we need something else here!
    
    init(type: InstructionType, code: String) {
        self.type = type
        self.code = code
    }
    
    var complexity: Int {
        if let instructions = self.instructions {
            return instructions.reduce(0) { (result, instruction) -> Int in
                if instruction.type == .whileInstruction || instruction.type == .forInstruction || instruction.type == .caseInstruction || instruction.type == .switchInstruction || instruction.type == .ifInstruction {
                    return result + 1 + instruction.complexity
                }
                
                return result + instruction.complexity
            }
        }
        return 0
    }
    
    var maxNestingDepth: Int {
        var maxDepth = 0
        
        if let instructions = self.instructions {
            let nestingDepths = instructions.map() {instruction in instruction.maxNestingDepth}
            maxDepth = nestingDepths.max() ?? 0
        }
        
        if self.type != .regularInstruction {
            maxDepth += 1
        }
        
        return maxDepth
    }
    
    var chainedMessageCalls: [[Instruction]] {
        var calls: [[Instruction]] = []
        
        if let instructions = self.instructions {
            for instruction in instructions {
                var chainedCalls = instruction.chainedMessageCalls
                
                if instruction.type == .regularInstruction {
                    if chainedCalls.count > 0 {
                        chainedCalls = chainedCalls.map() { subCalls in
                            var res = [instruction]
                            res.append(contentsOf: subCalls)
                            return res
                        }
                    } else {
                        chainedCalls.append([instruction])
                    }
                }
                calls.append(contentsOf: chainedCalls)
            }
        }
        
        return calls
    }
    
    var maxNumberOfChanedMessageCalls: Int {
        let lengthOfMessageCalls = self.chainedMessageCalls.map() { chain in
            return chain.count
        }
        
        return lengthOfMessageCalls.max() ?? 0
    }
}
