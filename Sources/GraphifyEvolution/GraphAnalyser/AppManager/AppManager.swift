//
//  AppManager.swift
//  
//
//  Created by Kristiina Rahkema on 16.09.2020.
//

protocol AppManager {
    func nextAppVersion() -> AppVersion?
    func newAppManager(path: String, appKey: String?) -> AppManager
    func analysisFinished(successfully: Bool)
    
    var project: Project? { get set }
}

extension AppManager {
    func analysisFinished(successfully: Bool) {
        if let project = project {
            project.analysisFinished = true
            if successfully {
                project.successfullyAnalysed = true
            } else {
                project.failed = true
            }
            
            project.save()
        }
    }
}
