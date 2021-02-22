//
//  BulkAppManager.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation

// Bulk will be later priority
class BulkAppManager: AppManager {
    let appManager: AppManager          // can be bulk analysis of evolution-project or single-project
    
    let jsonPath: String
    var parsedAppVersions: [AppVersion]?
    var appVersionsToAnalyse: [AppVersion] = []
    
    init(jsonPath: String, appManager: AppManager) {
        self.jsonPath = jsonPath
        self.appManager = appManager
    }
    
    func nextAppVersion() -> AppVersion? {
        /*
            Take path, read json info.
            For each app create new appVersion using appManager (can be either simple or gitmanager)
            
         */
        if self.parsedAppVersions == nil {
            self.parseJson()
        }
        
        if self.appVersionsToAnalyse.isEmpty {
            return nil
        }
        
        return appVersionsToAnalyse.removeFirst()
    }
    
    func parseJson() {
        self.parsedAppVersions = []
        self.appVersionsToAnalyse = []
        // parse json, enter appVersions into array
        // use appManager to create these app versions
    }
    
    func newAppManager(path: String, appKey: String?) -> AppManager {
        fatalError("BulkAppManager does not allow generation of new app managers")
    }
}
