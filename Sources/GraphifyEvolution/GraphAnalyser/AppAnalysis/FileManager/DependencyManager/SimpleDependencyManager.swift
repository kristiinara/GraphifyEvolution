//
//  SimpleDependencyManager.swift
//  ArgumentParser
//
//  Created by Kristiina Rahkema on 25.02.2021.
//

import Foundation

class SimpleDependencyManager: DependencyManager {
    func updateDependencies(path: String) {
        // do nothing
    }
    
    let ignoreWithPathComponents: [String]
    
    init(ignore: [String]) {
        self.ignoreWithPathComponents = ignore
    }
}
