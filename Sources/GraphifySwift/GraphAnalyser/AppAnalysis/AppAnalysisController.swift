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
                    continue
                }
            }
            
            changedPaths = Array(Set(changedPaths)) // remove duplicates
            print("changed files: \(changedPaths)")
            
            var updatedUsrs: [String] = []
            var addedUsrs: [String] = []
            
            //** Changed files (we can have removed classes, added classes or changed classes)
            var classesFromUpdatedFiles: [Class] = []
            
            for path in changedPaths {
                var classFound = false
                
                var classes = self.syntaxAnalyser.analyseFile(filePath: path, includePaths: includePaths)
                
                classLoop: for classInstance in classes {
                    for parentClass in parentClasses {
                        if classInstance.usr == parentClass.usr {
                            //TODO: check if class was actually changed!
                            
                            classInstance.parent = parentClass
                            
                            classesFromUpdatedFiles.append(classInstance)
                            updatedUsrs.append(classInstance.usr)
                            
                            continue classLoop
                        }
                    }
                    
                    //no parent class found --> we found an new class
                    print("New class found in changed file: \(classInstance.name)")
                    
                    classesFromUpdatedFiles.append(classInstance)
                }
            }
            
            /*
             TODO: check for additional parent!
             
             */
            newClasses.append(contentsOf: classesFromUpdatedFiles)
            
            for classInstance in classesFromUpdatedFiles {
                if let parent = classInstance.parent {
                    classInstance.saveParent()
                    var methods = handleMethods(newClass: classInstance, oldClass: parent, changes: changesForPaths)
                    methodsToBeHandled.append(contentsOf: methods)
                    
                    handleVariables(newClass: classInstance, oldClass: parent, changes: changesForPaths)
                } else {
                    if let potMethods = classInstance.potentialMethods {
                        classInstance.methods = potMethods
                        classInstance.saveMethods()
                        
                        methodsToBeHandled.append(contentsOf: potMethods)
                        classInstance.saveMethods()
                    }
                    
                    if let potVariables = classInstance.potentialVariables {
                        classInstance.variables = potVariables
                        classInstance.saveVariables()
                    }
                    
                    classInstance.save()
                }
            }
            
            
            //**
            
            for classInstance in parentClasses {
                print("class path: \(classInstance.path)")
                if removedPaths.contains(classInstance.path) {
                    print("in removed paths")
                    //do nothing?
                } else if renamedPaths.keys.contains(classInstance.path) {
                    print("in renamed paths")
                    
                    //TODO: run analysis, find out what the new name is, not as important right now
                    newClasses.append(classInstance)
                } else if changedPaths.contains(classInstance.path) {
                    print("in changed")
                    //don't do anything --> already handled
                } else {
                    print("in none")
                    if !updatedUsrs.contains(classInstance.usr) {
                        //was not removed, changed or renamed, so no change (also check if not already changed)
                        newClasses.append(classInstance)
                    }
                }
            }
//
//            if appVersion.parent?.analysedVersion == nil {
//                addedPaths = addedPaths + changedPaths
//            }
            
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
    
    func handleMethods(newClass: Class, oldClass: Class, changes: [String: [FileChange]]) -> [Method] {
        var oldNames: [String] = oldClass.methods.map() { value in return value.name}
        print("oldNames: \(oldNames)")

        var newMethods: [Method] = []
        var updatedMethods: [Method] = []
        var oldMethods: [Method] = []
        var methodsToBeHandled: [Method] = []
        
        if let methods = newClass.potentialMethods {
            print("going through potential methods, count: \(methods.count)")
            methodLoop: for method in methods {
                if !oldNames.contains(method.name) {
                    print("new method added: \(method.name)")
                    newMethods.append(method)
                    method.save() //TODO: do this here?
                    methodsToBeHandled.append(method)
                    
                    continue methodLoop
                }
                print("method exists: \(method.name)")
                
                if let startLine = method.startLine, let endLine = method.endLine {
                    print("lines: \(method.startLine) - \(method.endLine)")
                    if let changesForpath = changes[newClass.path] {
                        for fileChange in changesForpath {
                            for change in fileChange.changes {
                                print("change lines: \(change.newLines)")
                                if !(startLine < change.newLines.start && endLine < change.newLines.start) && !(startLine > (change.newLines.start + change.newLines.length) && endLine > (change.newLines.start + change.newLines.length)) {
                                    print("match")
                                    
                                    
                                    if oldNames.contains(method.name) {
                                        print("old name contains method.name")
                                        
                                    }
                                    
                                    for oldMethod in oldClass.methods {
                                        if method.name == oldMethod.name {
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
                                }
                            }
                        }
                        
                        for oldMethod in oldClass.methods {
                            if method.name == oldMethod.name {
                                oldMethods.append(oldMethod)
                            }
                        }
                    }
                }
            }
            
            
        }
        
        newClass.methods = newMethods + updatedMethods + oldMethods
        newClass.saveMethods()
        return methodsToBeHandled
    }
    
    func handleVariables(newClass: Class, oldClass: Class, changes: [String: [FileChange]]) {
        var oldNames: [String] = oldClass.variables.map() { value in return value.name}
        var newNames: [String] = newClass.potentialVariables!.map() { value in return value.name}

        var newVariables: [Variable] = []
        var updatedVariables: [Variable] = []
        var oldVariables: [Variable] = []
        
        print("variable oldNames: \(oldNames)")
        print("variable newNames: \(newNames)")

        if let variables = newClass.potentialVariables {
            print("going through potential variables")
            variableLoop: for variable in variables {
                if !oldNames.contains(variable.name) {
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
                                    
                                    
                                    if oldNames.contains(variable.name) {
                                        print("old name contains variable.name")
                                        
                                    }
                                    
                                    for oldVariable in oldClass.variables {
                                        if variable.name == oldVariable.name {
                                            print("prev. version of variable found")
                                            variable.save()
                                            variable.parent = oldVariable
                                        }
                                    }
                                    
                                    updatedVariables.append(variable)
                                    
                                    continue variableLoop
                                } else {
                                    print("no match")
                                }
                            }
                        }
                    }
                    
                    for oldVariable in oldClass.variables {
                        if variable.name == oldVariable.name {
                            oldVariables.append(oldVariable)
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
                print("Usr not found: \(usr)")
            }
        }
    }
}

//class BulkAnalysisController {
//
//}
