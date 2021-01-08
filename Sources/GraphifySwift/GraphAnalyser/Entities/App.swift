//
//  App.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation
import Theo

class App {
    var name: String
    //var code: String
    var versionNumber: Int = 1
    
    var usr: String? // USR??
    var commit: Commit?
    var parentCommit: Commit?
    var alternateParentCommit: Commit?
    
    var classes: [Class]
    
    var children: [App] = []
    weak var parent: App? {
        didSet {
            if let parent = self.parent {
                parent.relate(to: self, type: "CHANGED_TO")
            }
        }
    }
    var alternateApp: App? {
        didSet {
            if let alternateApp = self.alternateApp {
                alternateApp.relate(to: self, type: "CHANGED_TO")
            }
        }
    }
    
    init(name: String, classes: [Class]) {
        self.name = name
        self.classes = classes
        
        //self.save()
        for classInstance in classes {
            self.relate(to: classInstance, type: "APP_OWNS_CLASS")
        }
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
        oldNode.properties["usr"] = self.usr
        oldNode.properties["version_number"] = self.versionNumber
        oldNode.properties["commit"] = self.commit?.commit
        oldNode.properties["treee"] = self.commit?.tree
        oldNode.properties["time"] = self.commit?.date
        oldNode.properties["author"] = self.commit?.author
        oldNode.properties["message"] = self.commit?.message
        oldNode.properties["parent_commit"] = self.parentCommit
        oldNode.properties["alternate_parent_commit"] = self.alternateParentCommit
        
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
