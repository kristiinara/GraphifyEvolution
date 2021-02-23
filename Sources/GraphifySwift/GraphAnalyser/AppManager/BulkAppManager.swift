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
    var nextAppManager: AppManager?
    
    let folderPath: String
    let jsonPath: String
    var parsedAppVersions: [AppVersion]?
    //var appVersionsToAnalyse: [AppVersion] = []
    
    var allProjects: [Project]?
    var projectsToAnalyse: [Project] = []
    
    init(folderPath: String, jsonPath: String, appManager: AppManager) {
        if folderPath.hasSuffix("/") {
            self.folderPath = folderPath
        } else {
            self.folderPath = "\(folderPath)/"
        }
        
        self.jsonPath = jsonPath
        self.appManager = appManager
    }
    
    func nextAppVersion() -> AppVersion? {
        if allProjects == nil {
            parseJson()
        }
        
        var appManager: AppManager
        
        if let nextAppManager = self.nextAppManager {
            appManager = nextAppManager
        } else {
            if projectsToAnalyse.isEmpty {
                return nil
            }
            
            let nextProject = projectsToAnalyse.removeFirst()
            
            let path = "\(folderPath)\(nextProject.title)"
            self.gitClone(source: nextProject.source, path: path)
            
            appManager = self.appManager.newAppManager(path: path, appKey: nil)
            self.nextAppManager = appManager
        }
        
        if let nextAppVersion = appManager.nextAppVersion() {
            return nextAppVersion
        }
        
        self.nextAppManager = nil
        return self.nextAppVersion()
    }
    
    func gitClone(source: String, path: String) {
        let res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["clone", source, path])
            
        print("Git clone.. \(res)")
    }
    
    func parseJson() {
        self.parsedAppVersions = []
        // parse json, enter appVersions into array
        // use appManager to create these app versions
        
        var projects: [Project] = []
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: self.jsonPath))
            
            let json = try JSONSerialization.jsonObject(with: data,
                                                          options: JSONSerialization.ReadingOptions.mutableContainers) as Any

            if let dictionary = json as? [String: Any] {
                if let projectDicts = dictionary["projects"] as? [[String: Any]] {
                    for projectDict in projectDicts {
                        if let title = projectDict["title"] as? String, let source = projectDict["source"] as? String {
                            let newProject: Project = Project(title: title, source: source)
                            projects.append(newProject)
                        } else {
                            print("could not read title or source: \(projectDict)")
                        }
                    }
                } else {
                    print("No project in json")
                }
            } else {
                print("Incorrect json format")
            }
        } catch {
            fatalError("Parsing json failed: \(error.localizedDescription)")
        }
        
        print("Projects found in json file: \(projects.count)")
        
        self.allProjects = projects
        self.projectsToAnalyse = projects
    }
    
    func newAppManager(path: String, appKey: String?) -> AppManager {
        fatalError("BulkAppManager does not allow generation of new app managers")
    }
}

class Project {
    let title: String
    let source: String
    var tags: [String]?
    var description: [String]?
    var categories: [String]?
    var license: String?
    var stars: Int?

    init(title: String, source: String) {
        self.title = title
        self.source = source
    }
}
