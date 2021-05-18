//
//  JavaDependencyManager.swift
//  GraphifyEvolution
//
//  Created by Kristiina Rahkema on 03.05.2021.
//

import Foundation

protocol JavaDependencyManager: DependencyManager {
    func runDeLombok(path: String)
}

extension JavaDependencyManager {
    func runDeLombok(path: String) {
        /*
        // time grep --include=\*.java -rnw <path> -e "lombok" -l | xargs -I{} sh -c "java -jar lombock.jar delombok {} -p > '{}-tmp'"
        // find <path> -type f -name "*.java-tmp" | sed 's/\.java-tmp/.java/' | xargs -I{} mv "{}-tmp" "{}"
        
        print("running delombok")
        
        //var res = Helper.shell(launchPath: "/bin/bash", arguments: ["grep", "--include=\\*.java", "-rnw", path, "-e", "\"lombok\"", "-l", "|" ,"xargs", "-I{}", "sh", "-c", "\"java -jar lombock.jar delombok {} -p > '{}-tmp'\""])
        var res = Helper.shell(launchPath: "/bin/bash", arguments: ["JavaAnalyser/delomboc/delombock-all.sh", path])
        print(res)
        
        print("moving delomboked files")
        //res = Helper.shell(launchPath: "/bin/bash", arguments: ["find", path, "-type", "f", "-name", "\"*.java-tmp\"", "|", "sed", "'s/\\.java-tmp/.java/'", "|", "xargs", "-I{}", "mv", "\"{}-tmp\"", "\"{}\""])
        res = Helper.shell(launchPath: "/bin/bash", arguments: ["JavaAnalyser/delomboc/delombock-copy.sh", path])
        print(res)
 */
    }
}
