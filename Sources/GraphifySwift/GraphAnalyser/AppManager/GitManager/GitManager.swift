//
//  GitManager.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation

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
        
        print("finding parent commit")
        if let parentCommit = nextCommit.parentCommit {
            print("found parent commit")
            appVersion.parent = parentCommit.appVersion //TODO: check here if parent is already analysed if it exists?
            
            if let alternateParentCommit = nextCommit.alternateParentCommit {
                print("found alternateparent commit")
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
        //print("addCommit: \(commit.commit), \(commitsAdded)")
        var commitsAdded = commitsAdded
        
        if !commitsAdded.contains(commit.commit) {
            if let parentCommit = commit.parentCommit {
                if !commitsAdded.contains(parentCommit.commit) {
                    //print("add parent")
                    commitsAdded = addCommit(commit: parentCommit, commitsAdded: commitsAdded)
                }
            }
            
            if let alternateParentCommit = commit.alternateParentCommit {
                if !commitsAdded.contains(alternateParentCommit.commit) {
                    //print("add alternate parent")
                    commitsAdded = addCommit(commit: alternateParentCommit, commitsAdded: commitsAdded)
                }
            }
            
            // check again, because it might have been added when executing the above
            if !commitsAdded.contains(commit.commit) {
                //print("add commit itself")
                self.commitsToBeAnalysed.append(commit)
                commitsAdded.append(commit.commit)
                
                for child in commit.allChildren {
                    //print("add children")
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
        print("runGitCheckoutCommand")
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
            
            var res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "branch"])
            
        let mainBranch = 
            
            
            res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "stash"])
            res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "checkout", "master"])
            //print("Checkout command result: \(res)")
        } else {
            fatalError("Path for gitManager not defined")
        }
    }
    
    func runGitDiffCommand(forCommit: Commit) -> [FileChange] {
        print("runGitDiffCommand")
        // git diff -r a35ecb4b3a18f72888197bae92d38293981da335 --unified=0
        
        if forCommit.parent != "" {
            if let path = self.path {
                //print("path: \(path)")
               // let res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "diff", "-r", forCommit.parent, forCommit.commit])
                
              //  var args = ["--git-dir", path, "diff", "-r",forCommit.commit, forCommit.parent]
                var args = ["--git-dir", path, "diff", "-r", forCommit.parent, forCommit.commit]
                if let altparent = forCommit.alternateParentCommit {
                    args.append(altparent.commit)
                }
                
                let res = Helper.shell(launchPath: "/usr/bin/git", arguments: args)
                
                //print("git diff result: \(res)")
                
                var fileChanges: [FileChange] = []
                var currentFileChange: FileChange?
                var oldFile: String?
                var newFile: String?
                
                //print("git diff res: \(res)")
              
                for lineSubString in res.split(separator: "\n") {
                    let line = String(lineSubString)
                    
                    if line.starts(with: "diff") {
                        print("diff")
                        if let current = currentFileChange {
                            fileChanges.append(current)
                            currentFileChange = nil
                            oldFile = nil
                            newFile = nil
                        }
                        continue
                    }
                    
                    if line.starts(with: "--- a/") {
                        print("-- a/")
                        oldFile = String(line.dropFirst("--- a/".count))
                        //print("line: \(line), oldFile: \(oldFile)")
                        if oldFile == "/dev/null" {
                            oldFile = nil
                        }
                        
                        continue
                    }
                    
                    if line.starts(with: "+++ b/") {
                        print("+++ b/")
                        newFile = String(line.dropFirst("+++ b/".count))
                        //print("line: \(line), oldFile: \(newFile)")
                        if newFile == "/dev/null" {
                            newFile = nil
                        }
                        
                        continue
                    }
                    
                    if line.starts(with: "@@") {
                        print("@@")
                        if currentFileChange == nil {
                            //print("Line: \(line)")
                            //print("oldFile: \(oldFile), newFile: \(newFile)")
                            
                            
                            oldFile = (oldFile == nil ? nil : "\(String(self.path!.dropLast(".git".count)))\(oldFile!)")
                            
                            newFile = (newFile == nil ? nil : "\(String(self.path!.dropLast(".git".count)))\(newFile!)")
                            
                            currentFileChange = FileChange(oldPath: oldFile, newPath: newFile)
                        }
                        
                        //print("splitting by ,")
                        let values = line.split(separator: " ")
                        //print("values: \(values)")
                        
                        
                        // TODO: fix error from: ["@@", "-1", "+1", "@@"] --> no "," in numbers, normally -1,9 for example instead of -1
                        if !values[1].contains(",") {
                            continue
                        }
                        
                        let oldString = String("\(values[1])".dropFirst()).split(separator: ",")
                        let newString = String("\(values[2])".dropFirst()).split(separator: ",")
                        
                        //print("oldString: \(oldString), newString: \(newString)")
                        
                        //TODO: remove !
                        let oldLineNumbers = (start: Int(oldString[0])!, length: Int(oldString[1])!)
                        let newLineNumbers = (start: Int(oldString[0])!, length: Int(oldString[1])!)
                        
                        //print("oldLineNumbers: \(oldLineNumbers), newLineNumbers: \(newLineNumbers)")
                        
                        let newChange = Change(oldLines: oldLineNumbers, newLines: newLineNumbers)
                        
                        currentFileChange?.changes.append(newChange)
                        //print("new change added")
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
            
            let decoder = JSONDecoder()

            do {
                print("---------")
                let allCommits = try decoder.decode([Commit].self, from: json.data(using: .utf8)!)
                
                print("total number of commits found: \(allCommits.count)")
                for commit in allCommits {
                    //print(commit.commit)
                    //print("changes: \(commit.fileChanges?.count)")
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
