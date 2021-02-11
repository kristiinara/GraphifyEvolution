//
//  ExternalAnalyser.swift
//  GraphifySwift
//
//  Created by Kristiina Rahkema on 08.02.2021.
//

import Foundation

protocol ExternalAnalyser {
    func analyseApp(app:App)
    func analyseClass(classInstance:Class, app:App)
    func reset()
    
    var supportedLanguages: [Application.Analyse.Language] { get }
    var supportedLevel: Level { get }
    var readme: String { get }
}

enum Level {
    case applicationLevel, classLevel
}
