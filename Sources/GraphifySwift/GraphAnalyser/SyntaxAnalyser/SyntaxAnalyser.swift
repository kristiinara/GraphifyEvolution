//
//  SyntaxAnalyser.swift
//  
//
//  Created by Kristiina Rahkema on 16.09.2020.
//

import Foundation

protocol SyntaxAnalyser {
    func reset()
    func analyseFile(filePath: String, includePaths: [String]) -> [Class]
}
