//
//  MavenDependencyManager.swift
//  GraphifyEvolution
//
//  Created by Kristiina Rahkema on 30.04.2021.
//

import Foundation

class MavenDependencyManager: DependencyManager {
    func updateDependencies(path: String) {
        let pomPath: String
        
        if path.hasSuffix("/") {
            pomPath = path + "pom.xml"
        } else {
            pomPath = path + "/pom.xml"
        }
        
        if FileManager.default.fileExists(atPath: pomPath) {
            let res = Helper.shell(launchPath: "/bin/bash", arguments: ["mvn", "dependency:copy-dependencies", "-f", pomPath])
            print("Updated dependencies: \(res)")
        } else {
            print("No pom.xml at \(pomPath)")
        }
    }
    
    let ignoreWithPathComponents: [String]
    
    init(ignore: [String]) {
        self.ignoreWithPathComponents = ignore
    }
}
