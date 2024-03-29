//
//  GitManager.swift
//  
//
//  Created by Kristiina Rahkema on 23.10.2020.
//

import Foundation

class GitManager: AppManager {          // manager used for project evolution
    let path: String?
    var appKey: String?
    var startCommit: String?
    var started = false
    var onlyTags = false
    
    var commits: [Commit]?  //TODO: change type, maybe create new class/structure?
    var commitsToBeAnalysed: [Commit] = []
    
    init(path: String, appKey: String?) {
        var gitPath = path
        if !path.contains(".git") {
            if path.hasSuffix("/") {
                gitPath = "\(path).git"
            } else {
                gitPath = "\(path)/.git"
            }
        }
        
        self.path = gitPath
        self.appKey = appKey
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
        
        var nextCommit = self.commitsToBeAnalysed.removeFirst()
        //print("Next commit: \(nextCommit.commit), parent: \(nextCommit.parent), check parent: \(nextCommit.parentCommit?.commit)")
        
        if self.started == false{
            print("Searching for startCommit: \(startCommit)")
            if let startCommit = self.startCommit  {
                while nextCommit.commit != startCommit {
                    nextCommit = self.commitsToBeAnalysed.removeFirst()
                }
                print("found correct commit: \(nextCommit.commit)")
                self.started = true
            }
        }
        
        
        let appVersion = AppVersion(directoryPath: path)
        appVersion.appKey = appKey
        //appVersion.changedFilePaths
        nextCommit.appVersion = appVersion
        
        //print("finding parent commit")
        if let parentCommit = nextCommit.parentCommit {
            let changes = self.getChangesForCommit(commit: nextCommit, toCommit: parentCommit)
            
            if let parentAppVersion = parentCommit.appVersion {
                //print("found parent commit")
                appVersion.parent = AppVersionParent(appVersion: parentAppVersion, changes: changes)
                
            }
            
            if let altParentCommit = nextCommit.alternateParentCommit {
                if let altParentVersion = altParentCommit.appVersion {
                    //print("found alternateparent commit")
                    let altChanges = self.getChangesForCommit(commit: nextCommit, toCommit: altParentCommit)
                    
                    appVersion.alternateParent = AppVersionParent(appVersion: altParentVersion, changes: altChanges)
                }
            }
            
        }
        
        appVersion.commit = nextCommit
        
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
        
        //print("Total number of commits: \(self.commitsToBeAnalysed.count)")
        
        if let first = self.commitsToBeAnalysed.first {
            correctMasterBranch(forCommit: first)
        }
    }
    
    func findLeafNodeCommits(forCommit: Commit) -> [Commit] {
        var leafNodes: [Commit] = []
        
        if forCommit.children.count == 0 {
            leafNodes.append(forCommit)
        } else {
            for childCommit in forCommit.children {
                leafNodes.append(contentsOf: findLeafNodeCommits(forCommit: childCommit))
            }
        }
        
        return leafNodes
    }
    
    func correctMasterBranch(forCommit: Commit) {
        let deaultBranch = runDefaultBranchCommand()
        
        let leafNodeCommits = findLeafNodeCommits(forCommit: forCommit)
        
        for leafNodeCommit in leafNodeCommits {
            if let branch = runGetLastBranchCommand(forCommit: leafNodeCommit) {
                if deaultBranch.contains(branch) {
                    leafNodeCommit.branch = branch
                    var commit = leafNodeCommit
                    while let parent = commit.parentCommit {
                        parent.branch = branch
                        commit = parent
                    }
                }
            }
        }
    }
    
    //TODO: change so that it is not recursive anymore!
    func addCommit(commit: Commit, commitsAdded: [String]) -> [String] {
        //print("addCommit: \(commit.commit), \(commitsAdded)")
        var commitsAdded = commitsAdded
        
        if !commitsAdded.contains(commit.commit) {
            let branch = runGetBranchCommand(forCommit: commit)
            commit.branch = branch
            
            let tag = runGetTagCommand(forCommit: commit)
            commit.tag = tag
            
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
    
    
    func getChangesForCommit(commit: Commit, toCommit: Commit) -> [FileChange] {
        //print("getChangesForCommit")
        let changes = runGitDiffCommand(forCommit: commit, toCommit: toCommit)
        return changes
    }
    
    func newAppManager(path: String, appKey: String?) -> AppManager {
        return GitManager(path: path, appKey: appKey)
    }
    
    func runDefaultBranchCommand() -> String {
        //git rev-parse --abbrev-ref origin/HEAD
        
        if let path = self.path {
            let notGitPath = String(path.dropLast(".git".count))
            
            let res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "rev-parse", "--abbrev-ref", "origin/HEAD"])
            
            return res
        } else {
            fatalError("Path for gitManager not defined")
        }
    }
    
    func runGetTagCommand(forCommit: Commit) -> String? {
        // git tag --points-at <commit>
        if let path = self.path {
            let notGitPath = String(path.dropLast(".git".count))
            
            let res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "tag", "--points-at", forCommit.commit])
            
            if res.count > 0 {
                return res
            }
        } else {
            fatalError("Path for gitManager not defined")
        }
        
        return nil
    }
    
    func runGetLastBranchCommand(forCommit: Commit) -> String? {
        //  git name-rev --name-only --exclude=tags/*
        
        if let path = self.path {
            let notGitPath = String(path.dropLast(".git".count))
            
            let res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "name-rev", "--name-only", "--exclude=tags/*", forCommit.commit ])
            
            //print("Branch result: \(res)")
            let split = res.split(separator: "~")
            
            if let first = split.first {
                //print("setting branch: \(first)")
                return String(first)
            }
            return nil
        } else {
            fatalError("Path for gitManager not defined")
        }
    }
    
    func runGetBranchCommand(forCommit: Commit) -> String? {
      //  git name-rev --name-only --exclude=tags/*
        // does not work correctly when some branches are merged and deleted
     // git log <commit>..HEAD --ancestry-path --merges --oneline | tail -n 1
        if let path = self.path {
            let notGitPath = String(path.dropLast(".git".count))
            
            let res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "log", "\(forCommit.commit)..HEAD", "--ancestry-path", "--merges", "--oneline"])
            
            let merges = res.split(separator: "\n")
            
            //print("last merge commit: \(merges.last)")
            
            var lastMerge = ""
            if merges.count > 0 {
                lastMerge = String(merges[merges.count - 1])
            } else {
                return nil
            }
            
            let splitValues = lastMerge.split(separator: " ")
            var probableBranch = ""
            if splitValues.count > 0 {
                probableBranch = String(splitValues[splitValues.count - 1])
                probableBranch = probableBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return nil
            }
            
            //print("Branch result: \(lastMerge), branch: \(probableBranch)")
            return probableBranch
        } else {
            fatalError("Path for gitManager not defined")
        }
    }
    
    func runGitCheckoutCommand(forCommit: Commit) {
        //print("runGitCheckoutCommand")
        if let path = self.path {
            let notGitPath = String(path.dropLast(".git".count))
            
           // var res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "status"])
           // //print("Status command result: \(res)")
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
            var branchName = "master"
            if res.contains("* main") {
                branchName = "main"
            }
            
            res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "stash"])
            res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "--work-tree", notGitPath, "checkout", branchName])
            //print("Checkout command result: \(res)")
        } else {
            fatalError("Path for gitManager not defined")
        }
    }
    
    func runGitDiffCommand(forCommit: Commit, toCommit: Commit) -> [FileChange] {
        //print("runGitDiffCommand")
        // git diff -r a35ecb4b3a18f72888197bae92d38293981da335 --unified=0
        
        if forCommit.parent != "" {
            if let path = self.path {
                //print("path: \(path)")
                let res = Helper.shell(launchPath: "/usr/bin/git", arguments: ["--git-dir", path, "diff", "-r", toCommit.commit, forCommit.commit, "--unified=0"])
                
                //print("git diff result: \(res)")
                
                var fileChanges: [FileChange] = []
                var currentFileChange: FileChange?
                var oldFile: String?
                var newFile: String?
                
                //print("git diff res: \(res)")
              
                for lineSubString in res.split(separator: "\n") {
                    let line = String(lineSubString)
                    
                    if line.starts(with: "diff") {
                        //print("diff")
                        if let current = currentFileChange {
                            fileChanges.append(current)
                            currentFileChange = nil
                            oldFile = nil
                            newFile = nil
                        }
                        continue
                    }
                    
                    if line.starts(with: "--- a/") {
                        //print("-- a/")
                        oldFile = String(line.dropFirst("--- a/".count))
                        ////print("line: \(line), oldFile: \(oldFile)")
                        if oldFile == "/dev/null" {
                            oldFile = nil
                        }
                        
                        continue
                    }
                    
                    if line.starts(with: "+++ b/") {
                        //print("+++ b/")
                        newFile = String(line.dropFirst("+++ b/".count))
                        //print("line: \(line), oldFile: \(newFile)")
                        if newFile == "/dev/null" {
                            newFile = nil
                        }
                        
                        continue
                    }
                    
                    if line.starts(with: "@@") {
                        //print("@@")
                        //print("line: \(line)")
                        
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
            
                        /*
                         @@ -12 +12 @@ class House {
                         -    let doors: [String]
                         +    let doors: [Door]
                         */
                        
                        var oldLineNumbers: (start: Int, length: Int?) = (start: 0, length: nil)
                        var newLineNumbers: (start: Int, length: Int?) = (start: 0, length: nil)
                        
                        
                        // TODO: fix error from: ["@@", "-1", "+1", "@@"] --> no "," in numbers, normally -1,9 for example instead of -1
                        if values[1].contains(",") {
                            let oldString = String("\(values[1])".replacingOccurrences(of: "-", with: "")).split(separator: ",")
                            //print("oldString: \(oldString)")
                            
                            oldLineNumbers = (start: Int(oldString[0])!, length: Int(oldString[1])!)
                        } else {
                            //print("values1: \(values[1])")
                            oldLineNumbers = (start: Int("\(values[1])".trimmingCharacters(in: .whitespacesAndNewlines).dropFirst())!, length: nil)
                        }
                        
                        if values[2].contains(",") {
                            let newString = String("\(values[2])".replacingOccurrences(of: "+", with: "")).split(separator: ",")
                            //print("newString: \(newString)")
                            
                            newLineNumbers = (start: Int(newString[0])!, length: Int(newString[1])!)
                        } else {
                            //print("values2: \(values[2])")
                            let test = "\(values[2])".trimmingCharacters(in: .whitespacesAndNewlines).dropFirst()
                            
                            let start = Int(test)!
                            newLineNumbers = (start: start, length: nil)
                        }
                        
                        
                        
                        //print("oldString: \(oldString), newString: \(newString)")
                        
                        //TODO: remove !
                        
                        
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
            var args: [String] = ["--git-dir", path, "log", "--pretty=format:{%n \"commit\": \"%H\",%n \"abbCommit\": \"%h\",%n \"tree\": \"%T\", %n \"abbTree\": \"%t\", %n \"parent\": \"%P\", %n \"abbParent\": \"%p\", %n \"author\": \"%aN <%aE>\",%n \"date\": \"%ad\",%n \"authorTimestamp\": \"%at\",%n \"timestamp\": \"%ct\",%n \"message\": \"%f\"},"]
            
            if onlyTags {
                args.append("--tags")
                args.append("--no-walk")
            }
            let res = Helper.shell(launchPath: "/usr/bin/git", arguments: args)
            
            var json = "[\(res.dropLast())]"
            
            let decoder = JSONDecoder()

            do {
                print("---------")
                let allCommits = try decoder.decode([Commit].self, from: json.data(using: .utf8)!)
                
                print("total number of commits found: \(allCommits.count)")
                
                var commitDict: [String: Commit] = [:]
                for commit in allCommits {
                    if let path = self.path {
                        commit.url = path
                    }
                    commitDict[commit.commit] = commit
                }
                
                var commits: [Commit] = []
                
                if onlyTags {
                    var prevCommit: Commit? = nil
                    
                    for commit in allCommits {
                        if prevCommit == nil {
                            commits.append(commit)
                        }
                        
                        commit.parentCommit = prevCommit
                        prevCommit?.children.append(commit)
                        
                        prevCommit = commit
                    }
                } else {
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
