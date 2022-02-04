//
//  ExternalAnalyser.swift
//  GraphifySwift
//
//  Created by Kristiina Rahkema on 08.02.2021.
//

protocol ExternalAnalyser {
    func analyseApp(app:App)
    func analyseClass(classInstance:Class, app:App)
    func reset()
    
    func checkIfSetupCorrectly() -> Bool
    
    var supportedLanguages: [Application.Analyse.Language] { get }
    var supportedLevel: Level { get }
    var readme: String { get }
}

enum Level {
    case applicationLevel, classLevel
}
