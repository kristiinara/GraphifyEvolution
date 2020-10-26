//
//  AppAnalysisController.swift
//  
//
//  Created by Kristiina Rahkema on 14.09.2020.
//

import Foundation

class AppAnalysisController {
    let appManager: AppManager
    let syntaxAnalyser: SyntaxAnalyser
    let fileManager: LocalFileManager
    
    var appVersions: [AppVersion] = [] //TODO: do we really need this?
    var apps: [App] = []
    
    init(appManager: AppManager, syntaxAnalyser: SyntaxAnalyser, fileManager: LocalFileManager) {
        self.appManager = appManager
        self.syntaxAnalyser = syntaxAnalyser
        self.fileManager = fileManager
    }
    
    func runAnalysis() {
        var count = 0
        
        while let appVersion = self.appManager.nextAppVersion() {
            count += 1
            print("analysing app version \(count)")
//
//            continue
            
            self.syntaxAnalyser.reset()
            self.analyseAppVersion(appVersion: appVersion)
            
            if count > 4 {
               // break
            }
        }
        print("All app versions analysed, total: \(count)")
        
        print("Results: ")
        
        for app in self.apps {
            print("app: \(app.name)")
            printApp(app: app, prefix: "  ")
        }
    }
    
    func printApp(app: App, prefix: String) {
        print("\(prefix)classes:")
        for classInstance in app.classes {
            print("\(prefix)   \(classInstance.name) - version: \(classInstance.version)")
        }

        print("\(prefix)children (\(app.children.count):")
        for child in app.children {
            printApp(app: child, prefix: "\(prefix)")
        }
    }
    
    func printAppVersion(appVersion: AppVersion, prefix: String) {
        print("\(prefix)classes:")
        if let app = appVersion.analysedVersion {
            for classInstance in app.classes {
                print("\(prefix)   \(classInstance.name)")
            }
        }
        print("\(prefix)children:")
        for child in appVersion.children {
            printAppVersion(appVersion: child, prefix: "\(prefix)\(prefix)")
        }
        
    }
    
    func analyseAppVersion(appVersion: AppVersion) {
        //TODO: fix git stuff
        var includePaths: [String] = fileManager.fetchAllFiles(folderPath: "\(appVersion.directoryPath.dropLast(".git".count))").map() { url in return url.path}
        print("all include paths: \(includePaths)")
        
        var newClasses: [Class] = []
        var methodsToBeHandled: [Method] = []
        
        if let fileChanges = appVersion.changes {
            print("app version has changes: \(fileChanges.count)")
            
            var parentClasses: [Class] = []
            var existingClasses: [String:Class] = [:]
            
            if let parent = appVersion.parent?.analysedVersion {
                parentClasses = parent.classes
                existingClasses = parent.classes.reduce([String:Class]()) { (result, value) -> [String:Class] in
                    var newResult = result
                    newResult[value.usr] = value
                    return newResult
                }
            }
            
            var removedPaths: [String] = []
            var addedPaths: [String] = []
            var changedPaths: [String] = []
            var renamedPaths: [String:String] = [:]
            
            var changesForPaths: [String: [FileChange]] = [:]
            
            //var newClasses: [Class] = []
            
            for fileChange in fileChanges {
                print("change for files: \(fileChange.oldPath) - \(fileChange.newPath)")
                
                if fileChange.type == .removed {
                    print("change: removed")
                    let oldPath = fileChange.oldPath!
                    
                    removedPaths.append(oldPath)
                    continue
                }
                
                if fileChange.type == .renamed {
                    print("change: renamed")
                    let oldPath = fileChange.oldPath!
                    let newPath = fileChange.newPath!
                    renamedPaths[oldPath] = newPath
                    continue
                }
                
                if fileChange.type == .added {
                    print("change: added")
                    let newPath = fileChange.newPath!
                    addedPaths.append(newPath)
                    continue
                }
                
                if fileChange.type == .changed {
                    print("change: changed")
                    let newPath = fileChange.newPath!
                    changedPaths.append(newPath)
                    
                    var changesOnpath: [FileChange] = []
                    
                    if let existingChanges = changesForPaths[newPath] {
                        changesOnpath = existingChanges
                    }
                    
                    changesOnpath.append(fileChange)
                    changesForPaths[newPath] = changesOnpath
                    
                    //TODO: can it happen that something is changed and renamed?
                    
                    //TODO: analyse, get all classes and methods
                    // figure out which methods were added, removed or changed
                    continue
                }
            }
            
            print("changed files: \(changedPaths)")
            
            for classInstance in parentClasses {
                print("class path: \(classInstance.path)")
                if removedPaths.contains(classInstance.path) {
                    print("in removed paths")
                    //do nothing?
                } else if changedPaths.contains(classInstance.path) {
                    print("in changed paths")
                    //TODO: run analysis find out which methods/variables changed
                    var classes = self.syntaxAnalyser.analyseFile(filePath: classInstance.path, includePaths: includePaths)
                    print("file changed, classes in file: \(classes.count)")
                    print("classInstance.usr \(classInstance.usr)")
                    for newClassInstance in classes {
                        print("newClassInstance.usr: \(newClassInstance.usr)")
                        if classInstance.usr == newClassInstance.usr {
                            print("add changed class")
                            newClassInstance.parent = classInstance
                            newClasses.append(newClassInstance)
                            newClassInstance.version = classInstance.version + 1
                            //TODO: handle if there are multiple classes in the file!
                            // what happens if a class was added
                            
                            //TODO:
                            // changesForPaths --> get changes
                            // for each change find old method and new method --> either add, remove or modify method
                            
                            
 
                            var oldUsrs: [String] = classInstance.methods.map() { value in return value.usr}
                            var newUsrs: [String] = newClassInstance.methods.map() { value in return value.usr}

                            var newMethods: [Method] = []
                            var updatedMethods: [Method] = []
                            var oldMethods: [Method] = []
                            
                            if let methods = newClassInstance.potentialMethods {
                                print("going through potential methods, count: \(methods.count)")
                                methodLoop: for method in methods {
                                    if !oldUsrs.contains(method.usr) {
                                        print("new method added: \(method.name)")
                                        newMethods.append(method)
                                        method.save() //TODO: do this here?
                                        methodsToBeHandled.append(method)
                                        
                                        continue methodLoop
                                    }
                                    
                                    if let startLine = method.startLine, let endLine = method.endLine {
                                        print("lines: \(method.startLine) - \(method.endLine)")
                                        if let changesForpath = changesForPaths[newClassInstance.path] {
                                            for fileChange in changesForpath {
                                                for change in fileChange.changes {
                                                    print("change lines: \(change.newLines)")
                                                    if !(startLine < change.newLines.start && endLine < change.newLines.start) && !(startLine > (change.newLines.start + change.newLines.length) && endLine > (change.newLines.start + change.newLines.length)) {
                                                        print("match")
                                                        
                                                        
                                                        if oldUsrs.contains(method.usr) {
                                                            print("old usr contains method.usr")
                                                            
                                                        }
                                                        
                                                        for oldMethod in classInstance.methods {
                                                            if method.usr == oldMethod.usr {
                                                                print("prev. version of method found")
                                                                method.version = oldMethod.version + 1
                                                                method.save()
                                                                method.parent = oldMethod
                                                                methodsToBeHandled.append(method)
                                                                break
                                                            }
                                                        }
                                                        
                                                        updatedMethods.append(method)
                                                        
                                                        continue methodLoop
                                                    } else {
                                                        print("no match")
                                                        for oldMethod in classInstance.methods {
                                                            if method.usr == oldMethod.usr {
                                                                oldMethods.append(oldMethod)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                
                            }
                            
                            newClassInstance.methods = newMethods + updatedMethods + oldMethods
                            newClassInstance.saveMethods()
                            
                            //TODO: do the same for variables
                            
                            handleVariables(newClass: newClassInstance, oldClass: classInstance, changes: changesForPaths)
                            
                        }
                    }
                    
                } else if renamedPaths.keys.contains(classInstance.path) {
                    print("in renamed paths")
                    //TODO: run analysis, find out what the new name is, not as important right now
                    newClasses.append(classInstance)
                } else {
                    print("in none")
                    //was not removed, changed or renamed, so no change
                    newClasses.append(classInstance)
                }
            }
            
            if appVersion.parent?.analysedVersion == nil {
                addedPaths = addedPaths + changedPaths
            }
            
            for path in addedPaths {
                print("addedPath: \(path)")
                //TODO: run analysis
                var classes = self.syntaxAnalyser.analyseFile(filePath: path, includePaths: includePaths)
                newClasses.append(contentsOf: classes)
                for classInstance in classes {
                    classInstance.save()
                    
                    if let methods = classInstance.potentialMethods {
                        for method in methods {
                            method.save()
                            methodsToBeHandled.append(method)
                        }
                        
                        classInstance.methods = methods
                        classInstance.saveMethods()
                    }
                    
                    if let variables = classInstance.potentialVariables {
                        for variable in variables {
                            variable.save()
                        }
                        
                        classInstance.variables = variables
                        classInstance.saveVariables()
                    }
                }
                
                print("added classes: \(classes.count)")
            }
            
        } else {
            print("no changed file paths")
            
            if let parentVersion = appVersion.parent?.analysedVersion {
                print("parent exists, add no new classes")
                newClasses = parentVersion.classes
            } else {
                var filesToBeAnalysed = includePaths

                print("analyse \(filesToBeAnalysed.count) paths, changes: \(appVersion.changes?.count)")
                
                for file in filesToBeAnalysed {
                    var classes = self.syntaxAnalyser.analyseFile(filePath: file, includePaths: includePaths)
                    for classInstance in classes {
                        classInstance.save()
                        
                        if let methods = classInstance.potentialMethods {
                            for method in methods {
                                method.save()
                                methodsToBeHandled.append(method)
                            }
                            
                            classInstance.methods = methods
                            classInstance.saveMethods()
                        }
                        
                        if let variables = classInstance.potentialVariables {
                            for variable in variables {
                                variable.save()
                            }
                            
                            classInstance.variables = variables
                            classInstance.saveVariables()
                        }
                    }
                    //TODO: figure out how to set include paths (set for each analysis?)
                    
                    //print("Found class: \(syntaxTree.name)")
                    //TODO: figure out what to do with this class.. where should we define an app? if appVersion has no parent?
                    
                    newClasses.append(contentsOf: classes)
                }
            }
        }
        
        
        
        var app = App(name: "name", classes: newClasses)
        appVersion.analysedVersion = app
        print("new app with nr of classes: \(newClasses.count)")
        
        if let appVersionParent = appVersion.parent {
            print("appversion has parent")
            if let parentApp = appVersionParent.analysedVersion {
                print("set parent for app")
                parentApp.children.append(app)
                app.parent = parentApp
                app.versionNumber = parentApp.versionNumber + 1
                app.name = "\(app.versionNumber)"
                app.parentCommit = parentApp.commit
                
                print("parentapp number of children: \(parentApp.children.count)")
            }
            
            if let alternateParentApp = appVersion.alternateParent?.analysedVersion {
                app.alternateApp = alternateParentApp
                app.alternateParentCommit = alternateParentApp.commit
            }
        } else {
            print("appversion has no parent")
            self.appVersions.append(appVersion)
        }
        
        app.commit = appVersion.commit
        
        if(app.parent == nil) {
            print("app has no parent")
            self.apps.append(app)
        }
        app.save()
        
        for method in methodsToBeHandled {
            addCallAndUseConnections(method: method, app: app)
        }
        
        //applyChanges(appVersion: appVersion)
    }
    
    
    /*
    //TODO: finish this new method
    func handleClassesForNewApp(filesToBeAnalysed: [String], includePaths: [String]) -> [Class] {
        print("analyse \(filesToBeAnalysed.count) paths, changes: \(appVersion.changes?.count)")
        
        for file in filesToBeAnalysed {
            var classes = self.syntaxAnalyser.analyseFile(filePath: file, includePaths: includePaths)
            for classInstance in classes {
                classInstance.save()
                
                if let methods = classInstance.potentialMethods {
                    for method in methods {
                        method.save()
                        methodsToBeHandled.append(method)
                    }
                    
                    classInstance.methods = methods
                    classInstance.saveMethods()
                }
                
                if let variables = classInstance.potentialVariables {
                    for variable in variables {
                        variable.save()
                    }
                    
                    classInstance.variables = variables
                    classInstance.saveVariables()
                }
            }
            //TODO: figure out how to set include paths (set for each analysis?)
            
            //print("Found class: \(syntaxTree.name)")
            //TODO: figure out what to do with this class.. where should we define an app? if appVersion has no parent?
            
            newClasses.append(contentsOf: classes)
        }
    }
 */
    
    func handleVariables(newClass: Class, oldClass: Class, changes: [String: [FileChange]]) {
        var oldUsrs: [String] = oldClass.variables.map() { value in return value.usr}
        var newUsrs: [String] = newClass.variables.map() { value in return value.usr}

        var newVariables: [Variable] = []
        var updatedVariables: [Variable] = []
        var oldVariables: [Variable] = []
        
        if let variables = newClass.potentialVariables {
            print("going through potential methods")
            variableLoop: for variable in variables {
                if !oldUsrs.contains(variable.usr) {
                    print("new variable added: \(variable.name)")
                    newVariables.append(variable)
                    variable.save() //TODO: do this here?
                    continue variableLoop
                }
                
                if let startLine = variable.startLine, let endLine = variable.endLine {
                    print("lines: \(variable.startLine) - \(variable.endLine)")
                    if let changesForpath = changes[newClass.path] {
                        for fileChange in changesForpath {
                            for change in fileChange.changes {
                                print("change lines: \(change.newLines)")
                                if !(startLine < change.newLines.start && endLine < change.newLines.start) && !(startLine > (change.newLines.start + change.newLines.length) && endLine > (change.newLines.start + change.newLines.length)) {
                                    print("match")
                                    
                                    
                                    if oldUsrs.contains(variable.usr) {
                                        print("old usr contains variable.usr")
                                        
                                    }
                                    
                                    for oldVariable in oldClass.variables {
                                        if variable.usr == oldVariable.usr {
                                            print("prev. version of variable found")
                                            variable.save()
                                            variable.parent = oldVariable
                                        }
                                    }
                                    
                                    updatedVariables.append(variable)
                                    
                                    continue variableLoop
                                } else {
                                    print("no match")
                                    for oldVariable in oldClass.variables {
                                        if variable.usr == oldVariable.usr {
                                            oldVariables.append(oldVariable)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            
        }
        
        newClass.variables = newVariables + updatedVariables + oldVariables
        newClass.saveVariables()
    }
    
    func addCallAndUseConnections(method: Method, app: App) {
        var allMethods: [String: Method] = [:]
        var allVariables: [String: Variable] = [:]
        
        for classInstance in app.classes {
            for method in classInstance.methods {
                allMethods[method.usr] = method
            }
            
            for variable in classInstance.variables {
                allVariables[variable.usr] = variable
            }
        }
        
        for usr in method.calledUsrs {
            if let calledMethod = allMethods[usr] {
                method.relate(to: calledMethod, type: "CALLED") // TODO: check why no called methods
            } else if let usedVariable = allVariables[usr] {
                method.relate(to: usedVariable, type: "USED")
            } else {
                print("Usr not found")
            }
        }
    }
}

protocol LocalFileManager {
    func fetchAllFiles(folderPath: String) -> [URL]
}

class SwiftFileManager: LocalFileManager {
    func fetchAllFiles(folderPath: String) -> [URL] {
        var files: [URL] = []
        
        let resourceKeys : [URLResourceKey] = [
            .creationDateKey,
            .isDirectoryKey,
            .nameKey,
            .fileSizeKey
        ]
        
        let url = URL(fileURLWithPath: folderPath)
        
        let enumerator = FileManager.default.enumerator(
            at:                         url,
            includingPropertiesForKeys: resourceKeys,
            options:                    [.skipsHiddenFiles],
            errorHandler:               { (url, error) -> Bool in
                print("directoryEnumerator error at \(url): ", error)
                return true
        })!
        
        let ignore: [String] = []
        
        fileLoop: for case let fileURL as URL in enumerator {
            // ignoring files that contain the ignore string, but only looking at path relative to after the base url
            for ignorePath in ignore {
                var path = fileURL.path
                path = path.replacingOccurrences(of: url.path, with: "")
                if path.contains(ignorePath) {
                    continue fileLoop
                }
            }
            
            if fileURL.path.contains("+") {
                continue fileLoop
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                //print(fileURL.path, resourceValues.creationDate!, resourceValues.isDirectory!)
                
                if let name = resourceValues.name {
                    if name.hasSuffix(".swift") || name.hasSuffix(".h") {
                        //let size = resourceValues.fileSize!
                        //print("\(fileURL.path)")
                        //self.app.size = self.app.size + size
                        //TODO: fix size stuff
                        //self.classSizes.append(size)
                        
                         if (fileURL.path.contains("Tests")) {
                            //print("Ignore test files")
                        } else {
                            files.append(fileURL)
                        }
                    }
                }
            } catch {
                //TODO: do something if an error is thrown!
                print("Error")
            }
        }
        return files
    }
}

class CPPFileManager: LocalFileManager {
    func fetchAllFiles(folderPath: String) -> [URL] {
        var files: [URL] = []
        
        let resourceKeys : [URLResourceKey] = [
            .creationDateKey,
            .isDirectoryKey,
            .nameKey,
            .fileSizeKey
        ]
        
        let url = URL(fileURLWithPath: folderPath)
        
        let enumerator = FileManager.default.enumerator(
            at:                         url,
            includingPropertiesForKeys: resourceKeys,
            options:                    [.skipsHiddenFiles],
            errorHandler:               { (url, error) -> Bool in
                print("directoryEnumerator error at \(url): ", error)
                return true
        })!
        
        let ignore: [String] = []
        
        fileLoop: for case let fileURL as URL in enumerator {
            // ignoring files that contain the ignore string, but only looking at path relative to after the base url
            for ignorePath in ignore {
                var path = fileURL.path
                path = path.replacingOccurrences(of: url.path, with: "")
                if path.contains(ignorePath) {
                    continue fileLoop
                }
            }
            
            if fileURL.path.contains("+") {
                continue fileLoop
            }
            
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                //print(fileURL.path, resourceValues.creationDate!, resourceValues.isDirectory!)
                
                if let name = resourceValues.name {
                    if name.hasSuffix(".cpp") || name.hasSuffix(".h") {
                        //let size = resourceValues.fileSize!
                        //print("\(fileURL.path)")
                        //self.app.size = self.app.size + size
                        //TODO: fix size stuff
                        //self.classSizes.append(size)
                        
                         if (fileURL.path.contains("Tests")) {
                            //print("Ignore test files")
                        } else {
                            files.append(fileURL)
                        }
                    }
                }
            } catch {
                //TODO: do something if an error is thrown!
                print("Error")
            }
        }
        return files
    }
}

//class BulkAnalysisController {
//
//}

class AppVersion {
    var children: [AppVersion] = []
    var parent: AppVersion?
    var alternateParent: AppVersion?
    var directoryPath: String
    var commit: String?
    var changedFilePaths: [String]? {
        var paths: [String] = []
        
        if let changes = self.changes {
            for change in changes {
                if let newPath = change.newPath {
                    //TODO: fix this! Currently too ugly and won't work with all projects
                    paths.append("\(self.directoryPath.dropLast(".git".count))\(newPath)")
                }
            }
        } else {
            return nil
        }
        return paths
    }
    
    var changes: [FileChange]?
    
    var analysedVersion: App?
    
    init(directoryPath: String) {
        self.directoryPath = directoryPath
    }
    
    var first: Bool {
        return self.parent == nil
    }
    
    var analysed: Bool {
        return self.analysedVersion == nil
    }
}
