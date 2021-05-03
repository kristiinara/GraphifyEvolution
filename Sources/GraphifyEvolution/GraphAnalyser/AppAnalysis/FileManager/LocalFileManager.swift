//
//  LocalFileManager.swift
//  
//
//  Created by Kristiina Rahkema on 26.10.2020.
//

import Foundation

protocol LocalFileManager {
    func fetchAllFiles(folderPath: String) -> [URL]
    func fetchProjectFiles(folderPath: String) -> [URL]
    func updateDependencies(path: String)
    
    var ignoreWithPathComponents: [String] {get}
    var allowedEndings: [String] {get}
    
    var dependencyManager: DependencyManager {get}
}


extension LocalFileManager {
    func updateDependencies(path: String) {
        dependencyManager.updateDependencies(path: path)
    }
}
