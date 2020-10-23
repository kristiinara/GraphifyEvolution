//
//  SimpleAppManager.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation

class SimpleAppManager: AppManager {    // manager used for single project
    let path: String?
    var appVersionAnalysed = false
    
    init(path: String) {
        self.path = path
    }
    
    init() {
        self.path = nil
    }
    
    func nextAppVersion() -> AppVersion? {
        guard let path = path else {
            fatalError("Path for simpleAppManager not defined")
        }
        /*
            Take path, find all filePaths
            find all relevant analysis paths (look into old project)
         */
        if !appVersionAnalysed {
            appVersionAnalysed = true
            var appVersion = AppVersion(directoryPath: path)
        //appVersion.changedFilePaths.append(self.path) //TODO: replace with actual paths
        
            return appVersion
        } else {
            return nil
        }
    }
    
    func newAppManager(path: String) -> AppManager {
        return SimpleAppManager(path: path)
    }
}
