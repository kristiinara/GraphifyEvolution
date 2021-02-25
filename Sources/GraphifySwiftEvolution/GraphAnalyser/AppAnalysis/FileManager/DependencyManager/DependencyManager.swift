//
//  DependencyManager.swift
//  ArgumentParser
//
//  Created by Kristiina Rahkema on 25.02.2021.
//

protocol DependencyManager {
    func updateDependencies()
    var ignoreWithPathComponents: [String] { get }
}
