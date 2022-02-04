//
//  GradleDependencyManager.swift
//  GraphifyEvolution
//
//  Created by Kristiina Rahkema on 03.05.2021.
//
class GradleDependencyManager: JavaDependencyManager {
    func updateDependencies(path: String) {
        let dependenciesPath: String
        let gradlePath: String
        
        if path.hasSuffix("/") {
            dependenciesPath = path + "gradle_dependencies"
            gradlePath = path + "gradlew"
        } else {
            dependenciesPath = path + "/gradle_dependencies"
            gradlePath = path + "/gradlew"
        }
        
        print("running gradle dependencies")
        //let res = Helper.shell(launchPath: "/bin/bash", arguments: [gradlePath, "dependencies", "--gradle-user-home", dependenciesPath, "--project-dir", path])
        
        let res = Helper.shellAsync(launchPath: "/bin/bash", arguments: ["JavaAnalyser/delomboc/gradle.sh", dependenciesPath, path]) { (text, finished) in
            if(finished) {
                print(text)
                print("done gradle")
            } else {
                print("output gradle")
                print(text)
            }
            
        }
        print("Updated dependencies: \(res)")
        
        runDeLombok(path: path)
    }
    
    let ignoreWithPathComponents: [String]
    
    init(ignore: [String]) {
        self.ignoreWithPathComponents = ignore
    }
}
