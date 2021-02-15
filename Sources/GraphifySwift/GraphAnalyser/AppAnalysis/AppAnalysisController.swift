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
    let externalAnalysers: [ExternalAnalyser]
    
    var appVersions: [AppVersion] = [] //TODO: do we really need this?
    var apps: [App] = []
    
    var externalObjects: [String: ExternalObject] = [:]
    
    init(appManager: AppManager, syntaxAnalyser: SyntaxAnalyser, fileManager: LocalFileManager, externalAnalysers: [ExternalAnalyser]) {
        self.appManager = appManager
        self.syntaxAnalyser = syntaxAnalyser
        self.fileManager = fileManager
        self.externalAnalysers = externalAnalysers
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
        var finalClasses: [Class] = []
        var methodsToBeHandled: [Method] = []
        var variablesToBeHandled: [Variable] = []
        
        var pathWithoutGit = appVersion.directoryPath
        if pathWithoutGit.contains(".git") {
            pathWithoutGit = "\(appVersion.directoryPath.dropLast(".git".count))"
        }
        
        var includePaths: [String] = fileManager.fetchAllFiles(folderPath: pathWithoutGit).map() { url in return url.path}
        print("all include paths: \(includePaths)")
        
        var isMerge = false
        if appVersion.parent != nil && appVersion.alternateParent != nil {
            isMerge = true
        }
        
        var newClassVersions: [Class] = []
        
        if let parent = appVersion.parent {
            if let parentApp = appVersion.parent?.appVersion.analysedVersion {
                
                let parentClasses = parentApp.classes
                var altParentClasses: [Class] = []
                
                var intersectionChanged = [String]()
                var intersectionParentNew = [String]()
                var instersectonAltParentNew = parent.changedPaths
                var intersectionNew = parent.addedPaths
                
                print("parent: ")
                print("chagned: \(parent.changedPaths)")
                print("new: \(parent.addedPaths)")
                print("unchanged: \(parent.unchangedPaths)")
                
                if let altParent = appVersion.alternateParent {
                    print("altparent: ")
                    print("chagned: \(altParent.changedPaths)")
                    print("new: \(altParent.addedPaths)")
                    print("unchanged: \(altParent.unchangedPaths)")
                    
                    if let altParentApp = altParent.appVersion.analysedVersion {
                        altParentClasses = altParentApp.classes
                        print("altParentClasses: \(altParentClasses.map(){value in return value.name})")
                        
                        for classInstance in altParentClasses {
                            print("class: \(classInstance.name)")
                            print("methds: \(classInstance.methods.map() {value in return value.name})")
                        }
                    } else {
                        print("Alternate parent not analysed!")
                    }
                    
                    intersectionChanged = Array((Set(parent.changedPaths)).intersection(altParent.changedPaths))
                    intersectionParentNew = Array((Set(parent.addedPaths)).intersection(altParent.changedPaths))
                    instersectonAltParentNew = Array((Set(parent.changedPaths)).intersection(altParent.addedPaths))
                    intersectionNew = Array((Set(parent.addedPaths)).intersection(altParent.addedPaths))
                }
                
                var addedClasses: [String:Class] = [:]
                
                var combinedPaths: [String] = []
                combinedPaths.append(contentsOf: intersectionChanged)
                combinedPaths.append(contentsOf: intersectionNew)
                combinedPaths.append(contentsOf: intersectionParentNew)
                combinedPaths.append(contentsOf: instersectonAltParentNew)
                
                print("combinedPaths: \(combinedPaths)")
                
                pathLoop: for path in combinedPaths {
                    for ignore in fileManager.ignoreWithPathComponents {
                        if path.contains(ignore) {
                            print("ignore path \(path), contains ignore: \(ignore)")
                            continue pathLoop
                        }
                    }
                    
                    var correctEnding = false
                    for ending in fileManager.allowedEndings {
                        if path.hasSuffix(ending) {
                            correctEnding = true
                            print("path \(path) has correct ending \(ending)")
                            break
                        }
                    }
                    
                    if !correctEnding {
                        print("ignore path \(path), ending not correct")
                        continue pathLoop
                    }
                    
                    let classes = self.syntaxAnalyser.analyseFile(filePath: path, includePaths: includePaths)
                    
                    var classesToAdd: [Class] = []
                    
                    for classInstance in classes {
                        if let existingClass = addedClasses[classInstance.name] {
                            print("Class already added: \(classInstance.name) - \(classInstance.usr)")
                            //TODO: should we add methods from newly analysed class if class is somehow declared in multiple files?
                        } else {
                            addedClasses[classInstance.name] = classInstance
                            classesToAdd.append(classInstance)
                            classInstance.save()
                        }
                    }
                    
                    finalClasses.append(contentsOf: classesToAdd)
                    print("add classes (combined paths) : \(classesToAdd.map() { val in return val.name } )")
                }
                
                var remainingParentClasses: [String: Class] = [:]
                var notChangedClasses: [String: Class] = [:]
                
                for classInstance in parentClasses {
                    if let addedClass = addedClasses[classInstance.name] {
                        addedClass.parent = classInstance
                        addedClass.version = classInstance.version + 1
                        
                        var properties: [String:String] = [:]
                        if let commit = appVersion.commit?.commit {
                            properties["commit"] = commit
                        }
                        
                        classInstance.relate(to: addedClass, type: "CLASS_CHANGED_TO", properties: properties)
                        
                    } else if parent.unchangedPaths.contains(classInstance.path) {
                        finalClasses.append(classInstance)
                        print("add classes (unchanged from parent): \(classInstance.name)")
                        notChangedClasses[classInstance.name] = classInstance
                    } else if parent.removedPaths.contains(classInstance.path) {
                        // do nothing
                    } else {
                        print("remainingParentClass: \(classInstance.name) - commit: \(appVersion.commit?.commit), path: \(classInstance.path)")
                        remainingParentClasses[classInstance.name] = classInstance
                    }
                }
                
                if let altParent = appVersion.alternateParent {
                    for classInstance in altParentClasses {
                        if let addedClass = addedClasses[classInstance.name] {
                            addedClass.alternateParent = classInstance
                            //addedClass.saveParent()
                            
                            
                            var properties: [String:String] = [:]
                            if let commit = appVersion.commit?.commit {
                                properties["commit"] = commit
                            }
                            
                            classInstance.relate(to: addedClass, type: "CLASS_CHANGED_TO", properties: properties)
                            addedClass.save()
                            
                            let methods = handleMethodsMerge(newClass: addedClass, changesParent: parent.changesForPaths, changesAddParent: altParent.changesForPaths)
                            methodsToBeHandled.append(contentsOf: methods)
                            
                            var variables = handleVariablesMerge(newClass: addedClass, changesParent: parent.changesForPaths, changesAddParent: altParent.changesForPaths)
                            
                            variablesToBeHandled.append(contentsOf: variables)
                            
                            
                            // TODO: handle methods from both sides
                            // rel for parents
                            
                        } else if altParent.unchangedPaths.contains(classInstance.path) {
                            if let remainingParentClass = remainingParentClasses[classInstance.name] {
                                finalClasses.append(classInstance)
                                print("add classes (unchanged from altParent): \(classInstance.name)")
                                print("remainingParentClass.id: \(remainingParentClass.node.id), remainingParentClass.parent.id: \(remainingParentClass.parent?.node.id), classInstance.id: \(classInstance.node.id), classInstance.parent.id: \(classInstance.parent?.node.id)")
                                
                                if remainingParentClass.node.id != nil && remainingParentClass.node.id != classInstance.node.id && remainingParentClass.node.id != classInstance.parent?.node.id && remainingParentClass.node.id != classInstance.alternateParent?.node.id {
                                    
                                    remainingParentClass.alternateParent = classInstance
                                    //classInstance.saveParent()
                                    
                                    var properties: [String:String] = [:]
                                    if let commit = appVersion.commit?.commit {
                                        properties["commit"] = commit
                                    }
                                    
                                    remainingParentClass.relate(to: classInstance, type: "CLASS_CHANGED_TO", properties: properties)
                                    
                                    // add rel to methods where necessary (can start with Changed for each method?)
//                                    // TODO: handle methods (only parent to alt parent)
//                                    let methods = handleMethods(newClass: remainingParentClass, oldClass: classInstance, changes: parent.changesForPaths, isAlt: true)
//                                    //methodsToBeHandled.append(contentsOf: methods)
//
//                                    var variables = handleVariables(newClass: remainingParentClass, oldClass: classInstance, changes: parent.changesForPaths)
//                                    //variablesToBeHandled.append(contentsOf: variables)
                                    
                                    relateExistingMethods(newMethods: classInstance.methods, oldMethods: remainingParentClass.methods)
                                    
                                    relateExistingVariables(newVariables: classInstance.variables, oldVariables: remainingParentClass.variables)
                                } else {
                                    print("not adding new changed --> because already parent")
                                }
                                
                            } else if let notChangedClass = notChangedClasses[classInstance.name] {
                                // none were changed --> merge
                                //finalClasses.append(notChangedClass)
                                print("add classes (non changed -- merge): \(notChangedClass.name)")
                                
                                if notChangedClass.node.id == classInstance.node.id && notChangedClass.node.id != nil {
                                    // same class
                                } else {
                                    notChangedClass.alternateParent = classInstance
                                    
                                    var properties: [String:String] = [:]
                                    if let commit = appVersion.commit?.commit {
                                        properties["commit"] = commit
                                    }
                                    
                                    classInstance.relate(to: notChangedClass, type: "MERGE", properties: properties)
                                    
//                                    let methods = handleMethods(newClass: notChangedClass, oldClass: classInstance, changes: altParent.changesForPaths)
//                                    //methodsToBeHandled.append(contentsOf: methods)
//
//                                    var variables = handleVariables(newClass: notChangedClass, oldClass: classInstance, changes: altParent.changesForPaths)
//                                    //variablesToBeHandled.append(contentsOf: variables)
                                    
                                    relateExistingMethods(newMethods: notChangedClass.methods, oldMethods: classInstance.methods)
                                    
                                    relateExistingVariables(newVariables: notChangedClass.variables, oldVariables: classInstance.variables)
                                    
                                }
                                
                                //handle methods (only alt parent merge where methods not the same)
                            } else if parent.addedPaths.contains(classInstance.path) {
                                // class from altParent merged without changes
                                finalClasses.append(classInstance)
                            } else {
                                finalClasses.append(classInstance) //TODO: check if this is correct
                               // fatalError("Class not handled: \(classInstance.name) - \(classInstance.usr)")
                            }
                        } else if altParent.removedPaths.contains(classInstance.path) {
                            // do nothing
                        } else if let notChangedClass = notChangedClasses[classInstance.name] {
                            
                            if notChangedClass.parent?.node.id != classInstance.node.id && classInstance.node.id != notChangedClass.alternateParent?.node.id {
                                notChangedClass.alternateParent = classInstance
                                var properties: [String:String] = [:]
                                if let commit = appVersion.commit?.commit {
                                    properties["commit"] = commit
                                }
                                
                                classInstance.relate(to: notChangedClass, type: "CLASS_CHANGED_TO", properties: properties)
                                
    //                            let methods = handleMethods(newClass: classInstance, oldClass: notChangedClass, changes: altParent.changesForPaths)
    //                            // handle methods (only from alt parent to class)
    //                            //methodsToBeHandled.append(contentsOf: methods)
    //
    //                            var variables = handleVariables(newClass: classInstance, oldClass: notChangedClass, changes: altParent.changesForPaths)
    //                            //variablesToBeHandled.append(contentsOf: variables)
                                
                                relateExistingMethods(newMethods: notChangedClass.methods, oldMethods: classInstance.methods)
                                
                                relateExistingVariables(newVariables: notChangedClass.variables, oldVariables: classInstance.variables)
                            }
                            
                        } else if let remainingParentClass = remainingParentClasses[classInstance.name] {
                            print("Found remainingParentClass: \(remainingParentClass.name) - \(remainingParentClass.usr)")
                            fatalError("Found not handled remainingParentClass \(remainingParentClass.name) - should not happen!")
                        } else {
                            print("Class not handled: \(classInstance.name) - \(classInstance.usr)") //TODO: figure out how bad this is
                            finalClasses.append(classInstance)
                            //fatalError("Class not handled: \(classInstance.name) - \(classInstance.usr)")
                        }
                    }
                } else {
                    // no alt parent
                    for classInstance in [Class](addedClasses.values) {
                        if let parentClass = classInstance.parent, combinedPaths.contains(classInstance.path) {
                            //classInstance.saveParent()
                            
                            let methods = handleMethods(newClass: classInstance, oldClass: parentClass, changes: parent.changesForPaths)
                            methodsToBeHandled.append(contentsOf: methods)
                            
                            let variables = handleVariables(newClass: classInstance, oldClass: parentClass, changes: parent.changesForPaths)
                            variablesToBeHandled.append(contentsOf: variables)
                            
                            classInstance.save()
                        } else {
                            if let potMethods = classInstance.potentialMethods {
                                classInstance.methods = potMethods
                                classInstance.saveMethods()
                                
                                methodsToBeHandled.append(contentsOf: potMethods)
                            }
                            
                            if let potVariables = classInstance.potentialVariables {
                                classInstance.variables = potVariables
                                classInstance.saveVariables()
                                
                                variablesToBeHandled.append(contentsOf: potVariables)
                            }
                            
                            classInstance.save()
                        }
                    }
                    
                    for remainingParentClass in remainingParentClasses.values {
                        if parent.changedPaths.contains(remainingParentClass.path) {
                            // file was changed, so class was probably removed --> TODO: should check this
                            // do not add
                            print("RemainingParentClass missing, but from edited file, assume it was removed")
                        } else {
                            print("add from remainingParentClasses: \(remainingParentClass.name)")
                            finalClasses.append(remainingParentClass)
                        }
                    }
                }
                
                newClassVersions.append(contentsOf: addedClasses.values)
                
            } else {
                // Previous app version not yet analysed --> analyse whole app?
            }
        } else {
            // No parent, analyse all swift files, completely new app
            var filesToBeAnalysed = fileManager.fetchProjectFiles(folderPath: pathWithoutGit)

            print("analyse \(filesToBeAnalysed.count) paths, changes: \(appVersion.parent?.changes.count)")

            for file in filesToBeAnalysed {
                print("analyse file: \(file)")
                var classes = self.syntaxAnalyser.analyseFile(filePath: file.path, includePaths: includePaths)
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
                            variablesToBeHandled.append(variable)
                        }

                        classInstance.variables = variables
                        classInstance.saveVariables()
                    }
                }
                //TODO: figure out how to set include paths (set for each analysis?)

                //print("Found class: \(syntaxTree.name)")
                //TODO: figure out what to do with this class.. where should we define an app? if appVersion has no parent?

                finalClasses.append(contentsOf: classes)
                print("add classes (no parent, new app): \(classes.map() { val in return val.name } )")
            }
            newClassVersions.append(contentsOf: finalClasses)
        }
        
        var app = App(name: "name2", homePath: pathWithoutGit, classes: finalClasses)
        appVersion.analysedVersion = app
        print("new app with nr of classes: \(finalClasses.count)")
        
        if let appVersionParent = appVersion.parent {
            print("appversion has parent")
            if let parentApp = appVersionParent.appVersion.analysedVersion {
                print("set parent for app")
                parentApp.children.append(app)
                app.parent = parentApp
                app.versionNumber = parentApp.versionNumber + 1
                app.name = "\(app.versionNumber)"
                app.parentCommit = parentApp.commit
                
                print("parentapp number of children: \(parentApp.children.count)")
            }
            
            if let alternateParentApp = appVersion.alternateParent?.appVersion.analysedVersion {
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
            addCallAndUseConnectionsFrom(method: method, app: app)
        }
        addCallAndUseConnectionsTo(methods: methodsToBeHandled, variables: variablesToBeHandled, app: app)
        
        print("running external analysers for \(newClassVersions.map() {value in return value.name} )")
        for externalAnalyser in self.externalAnalysers {
            if externalAnalyser.supportedLevel == .applicationLevel {
                externalAnalyser.analyseApp(app: app)
            } else if externalAnalyser.supportedLevel == .classLevel {
                for classInstance in newClassVersions {
                    externalAnalyser.analyseClass(classInstance: classInstance, app: app)
                }
            } else {
                print("Unsupported external analyer level \(externalAnalyser.supportedLevel)")
            }
            externalAnalyser.reset()
        }
    }
    
    
//
//    func analyseAppVersion(appVersion: AppVersion) {
//        //TODO: fix git stuff
//        var includePaths: [String] = fileManager.fetchAllFiles(folderPath: "\(appVersion.directoryPath.dropLast(".git".count))").map() { url in return url.path}
//        print("all include paths: \(includePaths)")
//
//        var isMerge = false
//        if appVersion.parent != nil && appVersion.alternateParent != nil {
//            isMerge = true
//        }
//
//        var newClasses: [Class] = []
//        var methodsToBeHandled: [Method] = []
//        var variablesToBeHandled: [Variable] = []
//
//        if let fileChanges = appVersion.changes {
//            print("app version has changes: \(fileChanges.count)")
//
//            var parentClasses: [Class] = []
//            var existingClasses: [String:Class] = [:]
//
//            if let parent = appVersion.parent?.analysedVersion {
//                parentClasses = parent.classes
//                existingClasses = parent.classes.reduce([String:Class]()) { (result, value) -> [String:Class] in
//                    var newResult = result
//                    newResult[value.usr] = value
//                    return newResult
//                }
//            }
//
//            var removedPaths: [String] = []
//            var addedPaths: [String] = []
//            var changedPaths: [String] = []
//            var renamedPaths: [String:String] = [:]
//
//            var changesForPaths: [String: [FileChange]] = [:]
//
//            //var newClasses: [Class] = []
//
//            for fileChange in fileChanges {
//                print("change for files: \(fileChange.oldPath) - \(fileChange.newPath)")
//
//                if fileChange.type == .removed {
//                    print("change: removed")
//                    let oldPath = fileChange.oldPath!
//
//                    removedPaths.append(oldPath)
//                    continue
//                }
//
//                if fileChange.type == .renamed {
//                    print("change: renamed")
//                    let oldPath = fileChange.oldPath!
//                    let newPath = fileChange.newPath!
//                    renamedPaths[oldPath] = newPath
//                    continue
//                }
//
//                if fileChange.type == .added {
//                    print("change: added")
//                    let newPath = fileChange.newPath!
//                    addedPaths.append(newPath)
//                    continue
//                }
//
//                if fileChange.type == .changed {
//                    print("change: changed")
//                    let newPath = fileChange.newPath!
//                    changedPaths.append(newPath)
//
//                    var changesOnpath: [FileChange] = []
//
//                    if let existingChanges = changesForPaths[newPath] {
//                        changesOnpath = existingChanges
//                    }
//
//                    changesOnpath.append(fileChange)
//                    changesForPaths[newPath] = changesOnpath
//
//                    //TODO: can it happen that something is changed and renamed?
//                    continue
//                }
//            }
//
//            var altRemovedPaths: [String] = []
//            var altAddedPaths: [String] = []
//            var altChangedPaths: [String] = []
//            var altRenamedPaths: [String:String] = [:]
//
//            var altChangesForPaths: [String: [FileChange]] = [:]
//
//
//            /*
//             TODO: check for additional parent!
//
//             */
//
//            if isMerge {
//                // add to:  classesWithChangeInAlternativeParent
//                if let altParent = appVersion.alternateParent {
//                    if let changes = altParent.changes {
//
//                        //var newClasses: [Class] = []
//
//                        for fileChange in changes {
//                            print("change for files: \(fileChange.oldPath) - \(fileChange.newPath)")
//
//                            if fileChange.type == .removed {
//                                print("change: removed")
//                                let oldPath = fileChange.oldPath!
//
//                                altRemovedPaths.append(oldPath)
//                                continue
//                            }
//
//                            if fileChange.type == .renamed {
//                                print("change: renamed")
//                                let oldPath = fileChange.oldPath!
//                                let newPath = fileChange.newPath!
//                                altRenamedPaths[oldPath] = newPath
//                                continue
//                            }
//
//                            if fileChange.type == .added {
//                                print("change: added")
//                                let newPath = fileChange.newPath!
//                                altAddedPaths.append(newPath)
//                                continue
//                            }
//
//                            if fileChange.type == .changed {
//                                print("change: changed")
//                                let newPath = fileChange.newPath!
//                                altChangedPaths.append(newPath)
//
//                                var changesOnpath: [FileChange] = []
//
//                                if let existingChanges = altChangesForPaths[newPath] {
//                                    changesOnpath = existingChanges
//                                }
//
//                                changesOnpath.append(fileChange)
//                                altChangesForPaths[newPath] = changesOnpath
//
//                                //TODO: can it happen that something is changed and renamed?
//                                continue
//                            }
//                        }
//
//                        // changed in parent
//
//                            //changed in altParent
//                                    // find new class, set altParent class as well (so that it's possible to go through the methods), (ADD NEW METHODS IF changed in both, othervise ONLY REL)
//                                // new class, go through each method and do the same check
//                                // relationship parent class -CLASS_CHANGED-> new class
//                                // relationhsip altParent class -CLASS_CHANGED-> new class
//
//                            //not changed in altParent
//                                    // discard new class, add altParent class, handle methds the same way as before (ONLY REL)
//                                // reference to class in altParent
//                                // relationship parent class -CLASS_CHANGED-> altParent class
//
//                        // not changed in parent --> reference to class in parent
//                            //(already done anyway --> add additional relationships between parent and altParent classes)
//                                    // (ONLY REL) if altParent changed, handle methods for altParent --> parent
//
//                            //changed in altParent
//                                // reference to class in parent
//                                // relationship altParent class -CLASS_CHANGED-> parent class
//
//                            // not changed altParent
//                                // reference to class in parent
//                                // if not altParent class == parent class (how can we check this? check the id?)
//                                    // relationship altParent class -MERGE-> parent class
//
//
//                        // what if new class?
//                            // handle as changed?
//
//                            // new + changed --> new class, altParent class -CLASS_CHANGED-> new class
//                                // altParent as parent, handle methods as usual
//                            // new + not changed --> ref to altParent class
//                            // changed + new --> new class, parent class -CLASS_CHANGED-> new class
//                                // parent as parent, handle methods as usual
//                            // not changed + new --> ref to parent class
//                            // new + new --> new class
//                        // what if renamed class?
//                            // TODO later
//                        // what if deleted class?
//                            // cannot have change from other parent --> do nothing
//
//                    }
//                }
//            }
//
//            changedPaths = Array(Set(changedPaths)) // remove duplicates
//            print("changed files: \(changedPaths)")
//
//            altChangedPaths = Array(Set(changedPaths))
//            print("alt changed files: \(changedPaths)")
//
//            var commonChangedPaths = changedPaths
//            if isMerge {
//                // intersection of changedPats and altChangedPats + intersection new + changed and intersection changed + new
//                let interSectionChanged = (Set(changedPaths)).intersection(altChangedPaths)
//                let intersectionParentNew = (Set(addedPaths)).intersection(altChangedPaths)
//                let intersectionAltParentNew = (Set(changedPaths)).intersection(altAddedPaths)
//
//                commonChangedPaths = []
//                commonChangedPaths.append(contentsOf: interSectionChanged)
//                commonChangedPaths.append(contentsOf: intersectionParentNew)
//                commonChangedPaths.append(contentsOf: intersectionAltParentNew)
//            }
//
//            var updatedUsrs: [String] = []
//
//            //** Changed files (we can have removed classes, added classes or changed classes)
//            var classesFromUpdatedFiles: [Class] = []
//
//            for path in commonChangedPaths {
//                //var classFound = false
//
//                let classes = self.syntaxAnalyser.analyseFile(filePath: path, includePaths: includePaths)
//
//                classLoop: for classInstance in classes {
//                    for parentClass in parentClasses {
//                        if classInstance.usr == parentClass.usr {
//                            //TODO: check if class was actually changed!
//
//                            classInstance.parent = parentClass
//
//                            classesFromUpdatedFiles.append(classInstance)
//                            updatedUsrs.append(classInstance.usr)
//
//                            continue classLoop
//                        }
//                    }
//
//                    //no parent class found --> we found an new class
//                    print("New class found in changed file: \(classInstance.name)")
//
//                    classesFromUpdatedFiles.append(classInstance)
//                }
//            }
//
//
//            newClasses.append(contentsOf: classesFromUpdatedFiles)
//
//            for classInstance in classesFromUpdatedFiles {
//                if let parent = classInstance.parent {
//                    classInstance.saveParent()
//                    var methods = handleMethods(newClass: classInstance, oldClass: parent, changes: changesForPaths)
//                    methodsToBeHandled.append(contentsOf: methods)
//
//                    var variables = handleVariables(newClass: classInstance, oldClass: parent, changes: changesForPaths)
//                    variablesToBeHandled.append(contentsOf: variables)
//                } else {
//                    if let potMethods = classInstance.potentialMethods {
//                        classInstance.methods = potMethods
//                        classInstance.saveMethods()
//
//                        methodsToBeHandled.append(contentsOf: potMethods)
//                        classInstance.saveMethods()
//                    }
//
//                    if let potVariables = classInstance.potentialVariables {
//                        classInstance.variables = potVariables
//                        classInstance.saveVariables()
//
//                        variablesToBeHandled.append(contentsOf: potVariables)
//                    }
//
//                    classInstance.save()
//                }
//            }
//
//
//            //**
//
//            //TODO make this more reasonable in case of merge!!
//            for classInstance in parentClasses {
//                print("class path: \(classInstance.path)")
//                if removedPaths.contains(classInstance.path) {
//                    print("in removed paths")
//                    //do nothing?
//                } else if renamedPaths.keys.contains(classInstance.path) {
//                    print("in renamed paths")
//
//                    //TODO: run analysis, find out what the new name is, not as important right now
//                    newClasses.append(classInstance)
//                } else if commonChangedPaths.contains(classInstance.path) {
//                    print("in changed")
//                    //don't do anything --> already handled
//                } else {
//                    print("in none")
//                    if !updatedUsrs.contains(classInstance.usr) {
//                        if changedPaths.contains(classInstance.path) {
//                            //TODO: use altparent class
//                        } else {
//                            //was not removed, changed or renamed, so no change (also check if not already changed)
//                            newClasses.append(classInstance)
//                        }
//                    }
//                }
//            }
////
////            if appVersion.parent?.analysedVersion == nil {
////                addedPaths = addedPaths + changedPaths
////            }
//
//
//            var commonAddedPaths = addedPaths
//            if isMerge {
//                commonAddedPaths = Array((Set(addedPaths)).intersection(altAddedPaths))
//            }
//
//            for path in commonAddedPaths {
//                print("addedPath: \(path)")
//                //TODO: run analysis
//                var classes = self.syntaxAnalyser.analyseFile(filePath: path, includePaths: includePaths)
//                newClasses.append(contentsOf: classes)
//                for classInstance in classes {
//                    classInstance.save()
//
//                    if let methods = classInstance.potentialMethods {
//                        for method in methods {
//                            method.save()
//                            methodsToBeHandled.append(method)
//                        }
//
//                        classInstance.methods = methods
//                        classInstance.saveMethods()
//                    }
//
//                    if let variables = classInstance.potentialVariables {
//                        for variable in variables {
//                            variable.save()
//                            variablesToBeHandled.append(variable)
//                        }
//
//                        classInstance.variables = variables
//                        classInstance.saveVariables()
//                    }
//                }
//
//                print("added classes: \(classes.count)")
//            }
//
//        } else {
//            print("no changed file paths")
//
//            if let parentVersion = appVersion.parent?.analysedVersion {
//                print("parent exists, add no new classes")
//                newClasses = parentVersion.classes
//            } else {
//                var filesToBeAnalysed = includePaths
//
//                print("analyse \(filesToBeAnalysed.count) paths, changes: \(appVersion.changes?.count)")
//
//                for file in filesToBeAnalysed {
//                    var classes = self.syntaxAnalyser.analyseFile(filePath: file, includePaths: includePaths)
//                    for classInstance in classes {
//                        classInstance.save()
//
//                        if let methods = classInstance.potentialMethods {
//                            for method in methods {
//                                method.save()
//                                methodsToBeHandled.append(method)
//                            }
//
//                            classInstance.methods = methods
//                            classInstance.saveMethods()
//                        }
//
//                        if let variables = classInstance.potentialVariables {
//                            for variable in variables {
//                                variable.save()
//                                variablesToBeHandled.append(variable)
//                            }
//
//                            classInstance.variables = variables
//                            classInstance.saveVariables()
//                        }
//                    }
//                    //TODO: figure out how to set include paths (set for each analysis?)
//
//                    //print("Found class: \(syntaxTree.name)")
//                    //TODO: figure out what to do with this class.. where should we define an app? if appVersion has no parent?
//
//                    newClasses.append(contentsOf: classes)
//                }
//            }
//        }
//
//
//
//        var app = App(name: "name", classes: newClasses)
//        appVersion.analysedVersion = app
//        print("new app with nr of classes: \(newClasses.count)")
//
//        if let appVersionParent = appVersion.parent {
//            print("appversion has parent")
//            if let parentApp = appVersionParent.analysedVersion {
//                print("set parent for app")
//                parentApp.children.append(app)
//                app.parent = parentApp
//                app.versionNumber = parentApp.versionNumber + 1
//                app.name = "\(app.versionNumber)"
//                app.parentCommit = parentApp.commit
//
//                print("parentapp number of children: \(parentApp.children.count)")
//            }
//
//            if let alternateParentApp = appVersion.alternateParent?.analysedVersion {
//                app.alternateApp = alternateParentApp
//                app.alternateParentCommit = alternateParentApp.commit
//            }
//        } else {
//            print("appversion has no parent")
//            self.appVersions.append(appVersion)
//        }
//
//        app.commit = appVersion.commit
//
//        if(app.parent == nil) {
//            print("app has no parent")
//            self.apps.append(app)
//        }
//        app.save()
//
//        for method in methodsToBeHandled {
//            addCallAndUseConnectionsFrom(method: method, app: app)
//        }
//        addCallAndUseConnectionsTo(methods: methodsToBeHandled, variables: variablesToBeHandled, app: app)
//
//        //applyChanges(appVersion: appVersion)
//    }
 
        

    
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
    
    /*
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
                                            method.parent = oldMethod
                                            method.saveParent()
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
 */
    
    func handleMethodsMerge(newClass: Class, changesParent: [String: [FileChange]], changesAddParent: [String: [FileChange]]) -> [Method] {
        
        if let parent = newClass.parent, let altParent = newClass.alternateParent {
            var newMethods: [Method] = []
            var oldMethods: [Method] = []
            
            let methodsParent = findNewAndUpdatedMethods(newClass: newClass, oldClass: parent, changes: changesParent)
            
            let methodsAltParent = findNewAndUpdatedMethods(newClass: newClass, oldClass: altParent, changes: changesAddParent)
            
            var handledMethods: [String: Method] = [:]
            
            methodLoop: for method in methodsParent.new {
                for altMethod in (methodsAltParent.new + methodsAltParent.updated + methodsAltParent.old) {
                    if method.name == altMethod.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.name] == nil {
                            newMethods.append(altMethod)
                            handledMethods[altMethod.name] = altMethod
                            altMethod.saveParent()
                        }
                        
                        continue methodLoop
                    }
                }
            }
            
            methodLoop: for altMethod in methodsAltParent.new {
                for method in (methodsParent.new + methodsParent.updated + methodsParent.old) {
                    if method.name == altMethod.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.name] == nil {
                            newMethods.append(method)
                            handledMethods[method.name] = method
                            method.saveParent()
                        }
                        
                        continue methodLoop
                    }
                }
            }
            
            methodLoop: for method in methodsParent.old {
                for altMethod in (methodsAltParent.updated) {
                    if method.name == altMethod.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.name] == nil {
                            newMethods.append(method)
                            handledMethods[method.name] = method
                            method.altParent = altMethod.parent
                            method.saveAltParent()
                        }
                        
                        continue methodLoop
                    }
                }
                
                for altMethod in (methodsAltParent.old) {
                    if method.name == altMethod.name {
                        if handledMethods[method.name] == nil {
                            oldMethods.append(method)
                            handledMethods[method.name] = method
                            if method.node.id == nil || method.node.id != altMethod.node.id {
                                method.altParent = altMethod
                                method.saveAltParent()
                            }
                        }
                    }
                }
            }
            
            methodLoop: for altMethod in methodsAltParent.old {
                for method in (methodsParent.updated) {
                    if method.name == altMethod.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.name] == nil {
                            newMethods.append(altMethod)
                            handledMethods[altMethod.name] = altMethod
                            altMethod.altParent = method.parent
                            altMethod.saveAltParent()
                        }
                        
                        continue methodLoop
                    }
                }
            }
            
            methodLoop: for method in methodsParent.updated {
                for altMethod in (methodsAltParent.updated) {
                    if method.name == altMethod.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.name] == nil {
                            newMethods.append(method)
                            handledMethods[method.name] = method
                            method.altParent = altMethod.parent
                            method.saveAltParent()
                            method.saveParent()
                        }
                        
                        continue methodLoop
                    }
                }
            }
            
            newClass.methods = newMethods + oldMethods
            newClass.saveMethods()
            
            return newMethods
        }
        
        print("Could not find parent \(newClass.parent) or altParent \(newClass.alternateParent)")
        return []
    }
    
    
    func handleVariablesMerge(newClass: Class, changesParent: [String: [FileChange]], changesAddParent: [String: [FileChange]]) -> [Variable] {
        
        if let parent = newClass.parent, let altParent = newClass.alternateParent {
            var newVariables: [Variable] = []
            var oldVariables: [Variable] = []
            
            let variablesParent = findNewAndUpdatedVariables(newClass: newClass, oldClass: parent, changes: changesParent)
            
            let variablesAltParent = findNewAndUpdatedVariables(newClass: newClass, oldClass: altParent, changes: changesAddParent)
            
            var handledVariables: [String: Variable] = [:]
            
            variableLoop: for variable in variablesParent.new {
                for altVariable in (variablesAltParent.new + variablesAltParent.updated + variablesAltParent.old) {
                    if variable.name == altVariable.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledVariables[variable.name] == nil {
                            newVariables.append(altVariable)
                            handledVariables[altVariable.name] = altVariable
                            altVariable.saveParent()
                        }
                        
                        continue variableLoop
                    }
                }
            }
            
            variableLoop: for altVariable in variablesAltParent.new {
                for variable in (variablesParent.new + variablesParent.updated + variablesParent.old) {
                    if variable.name == altVariable.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledVariables[variable.name] == nil {
                            newVariables.append(variable)
                            handledVariables[variable.name] = variable
                            variable.saveParent()
                        }
                        
                        continue variableLoop
                    }
                }
            }
            
            variableLoop: for variable in variablesParent.old {
                for altVariable in (variablesAltParent.updated) {
                    if variable.name == altVariable.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledVariables[variable.name] == nil {
                            newVariables.append(variable)
                            handledVariables[variable.name] = variable
                            variable.altParent = altVariable.parent
                            variable.saveAltParent()
                        }
                        
                        continue variableLoop
                    }
                }
                
                for altVariable in (variablesAltParent.old) {
                    if variable.name == altVariable.name {
                        if handledVariables[variable.name] == nil {
                            oldVariables.append(variable)
                            handledVariables[variable.name] = variable
                            if(variable.node.id == nil || variable.node.id != altVariable.node.id) {
                                variable.altParent = altVariable
                                variable.saveAltParent()
                            }
                        }
                    }
                }
            }
            
            variableLoop: for altVariable in variablesAltParent.old {
                for variable in (variablesParent.updated) {
                    if variable.name == altVariable.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledVariables[variable.name] == nil {
                            newVariables.append(altVariable)
                            handledVariables[altVariable.name] = altVariable
                            altVariable.altParent = variable.parent
                            altVariable.saveAltParent()
                        }
                        
                        continue variableLoop
                    }
                }
            }
            
            variableLoop: for variable in variablesParent.updated {
                for altVariable in (variablesAltParent.updated) {
                    if variable.name == altVariable.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledVariables[variable.name] == nil {
                            newVariables.append(variable)
                            handledVariables[variable.name] = variable
                            variable.altParent = altVariable.parent
                            variable.saveAltParent()
                            variable.saveParent()
                        }
                        
                        continue variableLoop
                    }
                }
            }
            
            newClass.variables = newVariables + oldVariables
            newClass.saveVariables()
            
            return newVariables
        }
        
        print("Could not find parent \(newClass.parent) or altParent \(newClass.alternateParent)")
        return []
    }
    
    func handleMethods(newClass: Class, oldClass: Class, changes: [String: [FileChange]], isAlt: Bool = false) -> [Method] {
        
        let methods = findNewAndUpdatedMethods(newClass: newClass, oldClass: oldClass, changes: changes, isAlt: isAlt)
        
        for method in methods.new {
            method.save()
        }
        
        for method in methods.updated {
            method.save()
            
            if isAlt {
                method.saveAltParent()
            } else {
             //   if newClass.variables.count == 0 {
                    method.saveParent()
             //   }
            }
        }
        
        if newClass.methods.count == 0 {
            newClass.methods = methods.new  + methods.updated + methods.old
            newClass.saveMethods()
        }
        
        return methods.new + methods.updated
    }
    
    func relateExistingMethods(newMethods: [Method], oldMethods: [Method]) {
        methodLoop: for oldMethod in oldMethods {
            for newMethod in newMethods {
                if oldMethod.name == newMethod.name {
                    if oldMethod.node.id == newMethod.node.id {
                        //ignore and continue
                        continue methodLoop
                    } else {
                        newMethod.altParent = newMethod
                        newMethod.saveAltParent()
                        continue methodLoop
                    }
                }
            }
        }
    }
    
    func relateExistingVariables(newVariables: [Variable], oldVariables: [Variable]) {
        variableLoop: for oldVariable in oldVariables {
            for newVariable in newVariables {
                if oldVariable.name == newVariable.name {
                    if oldVariable.node.id == newVariable.node.id {
                        //ignore and continue
                        continue variableLoop
                    } else {
                        newVariable.altParent = oldVariable
                        newVariable.saveAltParent()
                        continue variableLoop
                    }
                }
            }
        }
    }
    
    func handleVariables(newClass: Class, oldClass: Class, changes: [String: [FileChange]]) -> [Variable] {
        
        let variables = findNewAndUpdatedVariables(newClass: newClass, oldClass: oldClass, changes: changes)
        
        for variable in variables.new {
            variable.save()
        }
        
        for variable in variables.updated {
            variable.save()
           // if newClass.variables.count == 0 {
                variable.saveParent()
           // }
        }
        
        if newClass.variables.count == 0 {
            newClass.variables = variables.new  + variables.updated + variables.old
            newClass.saveVariables()
        }
        
        return variables.new + variables.updated
    }
    
    func findNewAndUpdatedMethods(newClass: Class, oldClass: Class, changes: [String: [FileChange]], isAlt: Bool = false) -> (new: [Method], updated: [Method], old: [Method]) {
        var oldNames: [String] = oldClass.methods.map() { value in return value.name}
        
        var newNames: [String] = []
        var methodsToBeHandled = newClass.methods
        
        if methodsToBeHandled.count == 0, let potentialMethods = newClass.potentialMethods {
            methodsToBeHandled = potentialMethods
        }
        newNames = methodsToBeHandled.map() { value in return value.name}

        var newMethods: [Method] = []
        var updatedMethods: [Method] = []
        var oldMethods: [Method] = []
        
        print("method oldNames: \(oldNames)")
        print("method newNames: \(newNames)")

        if true {
            let methods = methodsToBeHandled
            //let methods = newClass.potentialMethods {
            print("going through potential methods")
            methodLoop: for method in methods {
                if !oldNames.contains(method.name) {
                    print("new method added: \(method.name)")
                    newMethods.append(method)
                    continue methodLoop
                }
                
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
                                            if method.node.id == nil || method.node.id != oldMethod.node.id {
                                                print("prev. version of method found")
                                                if isAlt {
                                                    method.altParent = oldMethod
                                                } else {
                                                    method.parent = oldMethod
                                                }
                                            } else {
                                                print("prev version of method found, but is itself")
                                            }
                                        }
                                    }
                                    
                                    updatedMethods.append(method)
                                    
                                    continue methodLoop
                                } else {
                                    print("no match")
                                }
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
        
        return (new: newMethods, updated: updatedMethods, oldMethods)
    }
    
    func findNewAndUpdatedVariables(newClass: Class, oldClass: Class, changes: [String: [FileChange]]) -> (new: [Variable], updated: [Variable], old: [Variable]) {
        var oldNames: [String] = oldClass.variables.map() { value in return value.name}
        
        var newNames: [String] = []
        var variablesToBeHandled = newClass.variables
        
        if variablesToBeHandled.count == 0, let potentialVariables = newClass.potentialVariables {
            variablesToBeHandled = potentialVariables
        }
        
        newNames = variablesToBeHandled.map() { value in return value.name}

        var newVariables: [Variable] = []
        var updatedVariables: [Variable] = []
        var oldVariables: [Variable] = []
        
        print("variable oldNames: \(oldNames)")
        print("variable newNames: \(newNames)")

        if true {
            //let variables = variablesToBeHandled {
            let variables = variablesToBeHandled
            print("going through potential variables")
            variableLoop: for variable in variables {
                if !oldNames.contains(variable.name) {
                    print("new variable added: \(variable.name)")
                    newVariables.append(variable)
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
                                            if variable.node.id == nil || variable.node.id != oldVariable.node.id {
                                                print("prev. version of variable found")
                                                variable.parent = oldVariable
                                            } else {
                                                print("prev version of variable found, but it is itself")
                                            }
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
        
        return (new: newVariables, updated: updatedVariables, oldVariables)
    }
    
    func addCallAndUseConnectionsFrom(method: Method, app: App) {
        var allMethods: [String: Method] = [:]
        var allVariables: [String: Variable] = [:]
        var allClasses: [String: Class] = [:]
        
        for classInstance in app.classes {
            for method in classInstance.methods {
                allMethods[method.usr] = method
            }
            
            for variable in classInstance.variables {
                allVariables[variable.usr] = variable
            }
            
            allClasses[classInstance.usr] = classInstance
            var parent = classInstance.parent
            while parent != nil {
                allClasses[parent!.usr] = classInstance
                parent = parent?.parent
                print("parent: \(parent?.name)")
            }
        }
        
        usrLoop: for instruction in method.allInstructions {
            if let usr = instruction.calledUsr {
                if let calledMethod = allMethods[usr] {
                    method.relate(to: calledMethod, type: "CALLS") // TODO: check why no called methods
                } else if let usedVariable = allVariables[usr] {
                    method.relate(to: usedVariable, type: "USES")
                } else if let usedClass = allClasses[usr] {
                    method.relate(to: usedClass, type: "CLASS_REF")
                } else {
                    if let external = externalObjects[usr] {
                        method.relate(to: external, type: "EXTERNAL_REF")
                    } else {
                        if let receiverUsr = instruction.receiverUsr {
                            if let classInstance = allClasses[receiverUsr] {
                                var name: String?
                                
                                if let calledName = instruction.calledName {
                                    name = calledName
                                } else if let calledName = instruction.parent?.calledName {
                                    name = calledName
                                }
                                
                                if let name = name {
                                    if let calledMethod = classInstance.methodWithName(name: name) {
                                        method.relate(to: calledMethod, type: "CALLS")
                                        continue usrLoop
                                    } else if let usedVariable = classInstance.variableWithName(name: name) {
                                        method.relate(to: usedVariable, type: "USES")
                                        continue usrLoop
                                    } else {
                                        print("Class \(classInstance.name) no method or variable with name \(name)")
                                    }
                                } else {
                                    print("Instruction does not have name: \(instruction.calledUsr)")
                                }
                            } else {
                                print("No class for usr found: \(receiverUsr)")
                            }
                        } else {
                            print("No receiverUsr for \(usr)")
                        }
                        
                        let external = ExternalObject(usr: usr)
                        external.save()
                        externalObjects[usr] = external
                        method.relate(to: external, type: "EXTERNAL_REF")
                    }
                    print("Usr not found (method from): \(usr)")
                }
            }
        }
    }
    
    func addCallAndUseConnectionsTo(methods: [Method], variables: [Variable], app: App) {
        var methodsToBeHandled: [String: Method] = [:]
        var variablesToBeHandled: [String: Variable] = [:]
        
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
        
        for method in methods {
            methodsToBeHandled[method.usr] = method
            
            var count = 0
            var parent = method.parent
            while let existingParent = parent {
                count += 1
                if count > 100 {
                    print("too many method parents")
                    break
                    
                }
                methodsToBeHandled[existingParent.usr] = method
                parent = existingParent.parent
                print("method parent \(method.name) \(method.version)")
            }
        }
        
        for variable in variables {
            variablesToBeHandled[variable.usr] = variable
            
            var count = 0
            var parent = variable.parent
            while let existingParent = parent {
                count += 1
                if count > 100 {
                    print("too many variable parents")
                    break
                }
                variablesToBeHandled[existingParent.usr] = variable
                parent = existingParent.parent
                print("variable parent \(variable.name) \(variable.version)")
            }
        }
        
        print("variables to be handled: \(variablesToBeHandled.keys)")
        print("methods to be handled: \(methodsToBeHandled.keys)")
        
        //TODO: check if this logic is correct
        for classInstance in app.classes {
            for method in classInstance.methods {
                if !methodsToBeHandled.keys.contains(method.usr) {
                    for usr in method.calledUsrs {
                        if let calledMethod = methodsToBeHandled[usr] {
                            method.relate(to: calledMethod, type: "CALLS") // TODO: check why no called methods
                        } else if let usedVariable = variablesToBeHandled[usr] {
                            method.relate(to: usedVariable, type: "USES")
                        } else {
                            print("Usr not found methodTo: \(usr)")
                        }
                    }
                }
            }
        }
    }
}

//class BulkAnalysisController {
//
//}
