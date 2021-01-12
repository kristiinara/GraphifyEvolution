//
//  Commit.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation

class Commit: Codable {
    var parentCommit: Commit?
    var alternateParentCommit: Commit?
    var children: [Commit] = []
    var commit: String
    var abbCommit: String
    var tree: String
    var abbTree: String
    var parent: String
    var abbParent: String
   // var body: String
    var author: String
    var date: String
    var message: String
    var appVersion: AppVersion?
    var fileChanges: [FileChange]?
    var branch: String?
    
//    init(commit: String, message: String) {
//        self.commit = commit
//        self.message = message
//    }
    
    var allChildren: [Commit] {
        return self.children + self.children.reduce([]) { result, commit in
            return result + commit.allChildren
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case commit, abbCommit, tree, abbTree, author, date, message, parent, abbParent
    }
}
