//
//  AppManager.swift
//  
//
//  Created by Kristiina Rahkema on 16.09.2020.
//

import Foundation

protocol AppManager {
    func nextAppVersion() -> AppVersion?
    func newAppManager(path: String) -> AppManager
}

// 2nd priority
class GitManager: AppManager {          // manager used for project evolution
    let path: String?
    var commits: [Commit]?  //TODO: change type, maybe create new class/structure?
    var commitsToBeAnalysed: [Commit] = []
    
    init(path: String) {
        self.path = path
    }
    
    init() {
        self.path = nil
    }
    
    func nextAppVersion() -> AppVersion? {
        guard let path = path else {
            fatalError("Path for gitAppManager not defined")
        }
        
        if self.commits == nil {
            self.getCommits()
        }
        
        /*
            Take path, get all commits from git. //TODO: add possibility to limit which commits to look at
            For each commmit create a new appVersion
            First app version contains whole project (initial commit)
            For each subsequent commit only updated/added/removed files are analysed
            previous commit is set as parent
            files to be analysed are set as filePaths
            //TODO: figure out where to find out which files to add as include paths/probably during analysis? Since we have to run some dependency management software? // option: figure this out later
         */
        
        if self.commits == nil || self.commitsToBeAnalysed.isEmpty {
            return nil
        }
        
        let nextCommit = self.commitsToBeAnalysed.removeFirst()
        print("Next commit: \(nextCommit.commit), parent: \(nextCommit.parent), check parent: \(nextCommit.parentCommit?.commit)")
        
        var appVersion = AppVersion(directoryPath: path)
        appVersion.changes = self.getChangesForCommit(commit: nextCommit)
        //appVersion.changedFilePaths
        nextCommit.appVersion = appVersion
        
        if let parentCommit = nextCommit.parentCommit {
            appVersion.parent = parentCommit.appVersion //TODO: check here if parent is already analysed if it exists?
            
            if let alternateParentCommit = nextCommit.alternateParentCommit {
                appVersion.alternateParent = alternateParentCommit.appVersion
            }
            
        } else {
            appVersion.changes = nil
        }
        
        appVersion.commit = nextCommit.commit
        
        self.runGitCheckoutCommand(forCommit: nextCommit)
        
        return appVersion
    }
    
    func getCommits() {
        self.runGitCheckoutMaster()
        self.runGitLogCommand()
        
        //self.commits = []
        
        var commitsAdded: [String] = []
        
        if let commits = self.commits { //TODO: figure out how to ensure that parent and alternate parent commits are always analysed first?
            for commit in commits {
                commitsAdded = addCommit(commit: commit, commitsAdded: commitsAdded)
            }
        }
        
        print("Total number of commits: \(self.commitsToBeAnalysed.count)")
    }
    
    func addCommit(commit: Commit, commitsAdded: [String]) -> [String] {
        print("addCommit: \(commit.commit), \(commitsAdded)")
        var commitsAdded = commitsAdded
        
        if !commitsAdded.contains(commit.commit) {
            if let parentCommit = commit.parentCommit {
                if !commitsAdded.contains(parentCommit.commit) {
                    print("add parent")
                    commitsAdded = addCommit(commit: parentCommit, commitsAdded: commitsAdded)
                }
            }
            
            if let alternateParentCommit = commit.alternateParentCommit {
                if !commitsAdded.contains(alternateParentCommit.commit) {
                    print("add alternate parent")
                    commitsAdded = addCommit(commit: alternateParentCommit, commitsAdded: commitsAdded)
                }
            }
            
            // check again, because it might have been added when executing the above
            if !commitsAdded.contains(commit.commit) {
                print("add commit itself")
                self.commitsToBeAnalysed.append(commit)
                commitsAdded.append(commit.commit)
                
                for child in commit.allChildren {
                    print("add children")
                     commitsAdded = addCommit(commit: child, commitsAdded: commitsAdded)
                }
            }
        }
        
        return commitsAdded
    }
    
    
    func getChangesForCommit(commit: Commit) -> [FileChange] {
        print("getChangesForCommit")
        let changes = runGitDiffCommand(forCommit: commit)
        return changes
    }
    
    func newAppManager(path: String) -> AppManager {
        return GitManager(path: path)
    }
    
    func runGitCheckoutCommand(forCommit: Commit) {
        if let path = self.path {
            let notGitPath = String(path.dropLast(".git".count))
            
           // var res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "status"])
           // print("Status command result: \(res)")
            var res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "stash"])
            res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "checkout", forCommit.commit])
            //print("Checkout command result: \(res)")
        } else {
            fatalError("Path for gitManager not defined")
        }
    }
    
    func runGitCheckoutMaster() {
        if let path = self.path {
            let notGitPath = String(path.dropLast(".git".count))
            
           // var res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "status"])
           // print("Status command result: \(res)")
            var res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "stash"])
            res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "checkout", "master"])
            //print("Checkout command result: \(res)")
        } else {
            fatalError("Path for gitManager not defined")
        }
    }
    
    func runGitDiffCommand(forCommit: Commit) -> [FileChange] {
        // git diff -r a35ecb4b3a18f72888197bae92d38293981da335 --unified=0
        
        if forCommit.parent != "" {
            if let path = self.path {
                //print("path: \(path)")
                let res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "diff", "-r", forCommit.parent, forCommit.commit])
                
                //print("git diff result: \(res)")
                
                var fileChanges: [FileChange] = []
                var currentFileChange: FileChange?
                var oldFile: String?
                var newFile: String?
              
                for lineSubString in res.split(separator: "\n") {
                    let line = String(lineSubString)
                    
                    if line.starts(with: "diff") {
                        if let current = currentFileChange {
                            fileChanges.append(current)
                            currentFileChange = nil
                            oldFile = nil
                            newFile = nil
                        }
                        continue
                    }
                    
                    if line.starts(with: "--- a/") {
                        oldFile = String(line.dropFirst("--- a/".count))
                        //print("line: \(line), oldFile: \(oldFile)")
                        if oldFile == "/dev/null" {
                            oldFile = nil
                        }
                        
                        continue
                    }
                    
                    if line.starts(with: "+++ b/") {
                        newFile = String(line.dropFirst("+++ b/".count))
                        //print("line: \(line), oldFile: \(newFile)")
                        if newFile == "/dev/null" {
                            newFile = nil
                        }
                        
                        continue
                    }
                    
                    if line.starts(with: "@@") {
                        if currentFileChange == nil {
                            //print("Line: \(line)")
                            //print("oldFile: \(oldFile), newFile: \(newFile)")
                            
                            
                            oldFile = (oldFile == nil ? nil : "\(String(self.path!.dropLast(".git".count)))\(oldFile!)")
                            
                            newFile = (newFile == nil ? nil : "\(String(self.path!.dropLast(".git".count)))\(newFile!)")
                            
                            currentFileChange = FileChange(oldPath: oldFile, newPath: newFile)
                        }
                        
                        let values = line.split(separator: " ")
                        let oldString = String("\(values[1])".dropFirst()).split(separator: ",")
                        let newString = String("\(values[2])".dropFirst()).split(separator: ",")
                        
                        //TODO: remove !
                        let oldLineNumbers = (start: Int(oldString[0])!, length: Int(oldString[1])!)
                        let newLineNumbers = (start: Int(oldString[0])!, length: Int(oldString[1])!)
                        
                        let newChange = Change(oldLines: oldLineNumbers, newLines: newLineNumbers)
                        
                        currentFileChange?.changes.append(newChange)
                    }
                    
                    
                }
                
                if let current = currentFileChange {
                    fileChanges.append(current)
                    currentFileChange = nil
                }
                
                return fileChanges
                
            } else {
                fatalError("Path for gitManager not defined")
            }
        } else {
            print("No parent!")
            return []
        }
    }
    
    func runGitLogCommand() {
        if let path = self.path {
            let res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "log", "--pretty=format:{%n \"commit\": \"%H\",%n \"abbCommit\": \"%h\",%n \"tree\": \"%T\", %n \"abbTree\": \"%t\", %n \"parent\": \"%P\", %n \"abbParent\": \"%p\", %n \"author\": \"%aN <%aE>\",%n \"date\": \"%ad\",%n \"message\": \"%f\"},"])
           var json = "[\(res.dropLast())]"
            
            */
            let decoder = JSONDecoder()

            do {
                print("---------")
                let allCommits = try decoder.decode([Commit].self, from: json.data(using: .utf8)!)
                
                print("total number of commits found: \(allCommits.count)")
                for commit in allCommits {
                    print(commit.commit)
                    print("changes: \(commit.fileChanges?.count)")
                    //print(commit.children)
                }
                
                var commitDict: [String: Commit] = [:]
                for commit in allCommits {
                    commitDict[commit.commit] = commit
                }
                
                var commits: [Commit] = []
                
                for commit in allCommits { //can have two parents! //TODO: add both as parents!
                    if commit.parent == nil || commit.parent == "" {
                        commits.append(commit)
                    } else {
                        let splitParents = commit.parent.split(separator: " ")
                        
                        if splitParents.count > 1 {
                            if let parent = commitDict[String(splitParents[0])] {
                                commit.parentCommit = parent
                                parent.children.append(commit) // TODO: do we create a retain cycle here?
                            }
                            
                            if let otherParent = commitDict[String(splitParents[1])] {
                                commit.alternateParentCommit = otherParent
                            }
                        }
                        
                        if let parent = commitDict[commit.parent] {
                            commit.parentCommit = parent
                            parent.children.append(commit) // TODO: do we create a retain cycle here?
                        }
                    }
                }
                
                self.commits = commits
            } catch {
                print("could not parse commit! \(error.localizedDescription)")
            }
            
        } else {
            fatalError("Path for gitManager not defined")
        }
    }
}

class Helper {
    static func shell(launchPath path: String, arguments args: [String]) -> String {
        let task = Process()
        task.launchPath = path
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        task.waitUntilExit()

        return(output!)
    }
}

class FileChange {
    enum FileChangeType {
        case changed, added, removed, renamed
    }
    
    var oldPath: String?
    var newPath: String?
    var changes: [Change] = []
    
    var type: FileChangeType {
        if oldPath == nil {
            return .added
        }
        if newPath == nil {
            return .removed
        }
        
        if oldPath != newPath {
            return .renamed
        }
        
        return .changed
    }
    
    init(oldPath: String?, newPath: String?) {
        self.oldPath = oldPath
        self.newPath = newPath
    }
}

class Change {
    enum ChangeType {
        case changed, added, removed, confused
    }
    
    var type: ChangeType {
        if oldLines.length == 0 && newLines.length == 0 {
            return .confused
        } else if oldLines.length == 0 {
            return .added
        } else if newLines.length == 0 {
            return .removed
        } else {
            return .changed
        }
    }
    var oldLines: (start: Int, length: Int)
    var newLines: (start: Int, length: Int)
    
    init(oldLines: (start: Int, length: Int), newLines: (start: Int, length: Int)) {
        self.oldLines = oldLines
        self.newLines = newLines
    }
}

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

// first priority
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
    
    func newAppManager(path: String) -> AppManager {
        fatalError("BulkAppManager does not allow generation of new app managers")
    }
}
