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
    
    var project: Project? = nil // holds the last project that was analysed
    
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
            
            if let allProjects = allProjects {
                for project in allProjects {
                    let _ = project.save()
                }
            } else {
                print("Still no projects?")
            }
        }
        
        var appManager: AppManager?
        
        if let nextAppManager = self.nextAppManager {
            appManager = nextAppManager
        } else {
            if projectsToAnalyse.isEmpty {
                return nil
            }
            
            while(!projectsToAnalyse.isEmpty) {
                let nextProject = projectsToAnalyse.removeFirst()
                
                if let name = nextProject.title, let source = nextProject.source {
                    let path = "\(folderPath)\(name)"
                    
                    self.gitClone(source: source, path: path)
                    
                    appManager = self.appManager.newAppManager(path: path, appKey: nil)
                    appManager?.project = nextProject
                    
                    nextProject.analysisStarted = true
                    let _ = nextProject.save()
                    self.project = nextProject
                    
                    self.nextAppManager = appManager
                    break
                    
                } else {
                    nextProject.failed = true
                    let _ = nextProject.save()
                    continue
                }
            }
            
        }
        
        if let appManager = appManager {
            if let nextAppVersion = appManager.nextAppVersion() {
                return nextAppVersion
            }
            
            self.nextAppManager = nil
            return self.nextAppVersion()
        } else {
            return nil
        }
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
                        projects.append(parseProject(json: projectDict))
                    }
                } else {
                    print("No project in json")
                }
            } else if let projectDicts = json as? [[String: Any]] {
                for projectDict in projectDicts {
                    projects.append(parseProject(json: projectDict))
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

func parseProject(json: [String: Any]) -> Project {
    var title = json["title"] as? String
    if title == nil {
        title = json["name"] as? String
    }
    
    var source = json["source"] as? String
    if source == nil {
        source = json["repository_url"] as? String
    }
    
    if var titleString = title {
        if titleString.hasSuffix(".json") {
            // do nothing, but we will not handle this kind of a project
        } else if titleString.starts(with: "https://github.com/") {
            source = titleString
            
            if titleString.hasSuffix(".git") {
                titleString = titleString.replacingOccurrences(of: ".git", with: "")
            }
            title = titleString.replacingOccurrences(of: "https://github.com/", with: "")
            
        } else if titleString.starts(with: "github.com/") {
            source = "https://\(titleString)"
            
            if titleString.hasSuffix(".git") {
                titleString = titleString.replacingOccurrences(of: ".git", with: "")
            }
            title = titleString.replacingOccurrences(of: "github.com/", with: "")
        } else if titleString.components(separatedBy: "/").count > 2 {
            if titleString.starts(with: "https://") {
                source = titleString
                title = titleString.replacingOccurrences(of: "https://", with: "")
            } else {
                source = "https://\(titleString)"
            }
        }
    }
    
    var tags = json["tags"] as? [String]
    if tags == nil {
        if let keywords = json["keywords"] as? String {
            tags = keywords.components(separatedBy: ",")
        }
    }
    
    var description = json["description"] as? [String]
    if description == nil {
        if let descriptionString = json["description"] as? String {
            description = [descriptionString]
        }
    }
    
    let categorites = json["categories"] as? [String]
    
    var license = json["license"] as? String
    if license == nil {
        license = json["licenses"] as? String
    }
    
    let stars = json["stars"] as? Int
    
    let project = Project(title: title, source: source)
    
    project.tags = tags
    project.description = description
    project.categories = categorites
    project.license = license
    project.stars = stars
    
    return project
}

class Project {
    let title: String?
    let source: String?
    var failed = false
    var successfullyAnalysed = false
    var analysisStarted = false
    var analysisFinished = false
    
    var tags: [String]?
    var description: [String]?
    var categories: [String]?
    var license: String?
    var stars: Int?

    init(title: String?, source: String?) {
        self.title = title
        self.source = source
    }

    var nodeSet: Node?
}

extension Project: Neo4jObject {
    typealias ObjectType = Project
    static var nodeType = "Project"
    
    var updatedNode: Node {
        let oldNode = self.node
        
        oldNode.properties["title"] = self.title
        oldNode.properties["source"] = self.source
        oldNode.properties["failed"] = self.failed
        oldNode.properties["successfullyAnalysed"] = self.successfullyAnalysed
        oldNode.properties["analysisFinished"] = self.analysisFinished
        oldNode.properties["tags"] = self.tags != nil ? "\(self.tags!)" : nil
        oldNode.properties["description"] = self.description != nil ? "\(self.description!)" : nil
        oldNode.properties["categories"] = self.categories != nil ? "\(self.categories!)" : nil
        oldNode.properties["license"] = self.license
        oldNode.properties["stars"] = self.stars
        oldNode.properties["analysisStarted"] = self.analysisStarted
        
        self.nodeSet = oldNode
        
        return oldNode
    }
    
    var node: Node {
        if nodeSet == nil {
            nodeSet = self.newNode()
        }
        
        return nodeSet!
    }
}
