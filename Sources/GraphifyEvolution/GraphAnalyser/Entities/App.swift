//
//  App.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//
import Theo

class App: Codable {
    var name: String
    var appKey: String?
    //var code: String
    var versionNumber: Int = 1
    
    var usr: String?
    var commit: Commit?
    var parentCommit: Commit?
    var alternateParentCommit: Commit?
    var homePath: String
    
    var classes: [Class]
    
    var children: [App] = []
    weak var parent: App? 
    weak var alternateApp: App?
    
    var appIdentifier: String {
        if let commit = self.commit?.gitCommit.commit {
            return "\(self.name)-\(commit)"
        }
        return self.name
    }
    
    init(name: String, homePath: String, classes: [Class]) {
        self.name = name
        self.homePath = homePath
        self.classes = classes
        
        //self.save()
        for classInstance in classes {
            classInstance.save()
            self.relate(to: classInstance, type: "APP_OWNS_CLASS")
        }
    }
    
    var id: Int? {
        return self.nodeSet?.id
    }
    
    var nodeSet: Node?
}

extension App: Neo4jObject {
    typealias ObjectType = App
    static var nodeType = "App"
    
    /*
    static func initFrom(node: Node) -> App {
        var app = App(name: "", classes: [])
        
        if let name = node["name"] as? String {
            app.name = name
        }
        
        if let usr = node["usr"]  as? String {
            app.usr = usr
        }
        
        if let versionNumber = node["version_number"] as? Int {
            app.versionNumber = versionNumber
        }
        
        app.nodeSet = node
        
        return app
    }
 */
    
    var updatedNode: Node {
        let oldNode = self.node
        
        oldNode.properties["name"] = self.name
        oldNode.properties["appKey"] = self.appKey
        oldNode.properties["usr"] = self.usr
        oldNode.properties["version_number"] = self.versionNumber
        oldNode.properties["commit"] = self.commit?.gitCommit.commit
        oldNode.properties["tree"] = self.commit?.gitCommit.tree
        oldNode.properties["branch"] = self.commit?.branch
        oldNode.properties["branch_debug"] = self.commit?.branchDebug
        oldNode.properties["tag"] = self.commit?.tag?.trimmingCharacters(in:.whitespaces)
        oldNode.properties["time"] = self.commit?.gitCommit.date
        oldNode.properties["timestamp"] = self.commit?.gitCommit.timestamp
        oldNode.properties["author_timestamp"] = self.commit?.gitCommit.authorTimestamp
        oldNode.properties["repository_url"] = self.commit?.url
        oldNode.properties["author"] = self.commit?.gitCommit.author
        oldNode.properties["message"] = self.commit?.gitCommit.message
        oldNode.properties["parent_commit"] = self.parentCommit?.gitCommit.commit
        oldNode.properties["alternate_parent_commit"] = self.alternateParentCommit?.gitCommit.commit
        
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
