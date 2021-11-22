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
    var noSourceCodeAnalysis = false
    
    //var appVersions: [AppVersion] = [] //TODO: do we really need this?
    //var apps: [App] = []
    
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
        self.appManager.analysisFinished(successfully: true) //TODO: probably add possibility to say that it was not successful??
        
        //print("Results: ")
        
        //for app in self.apps {
            //print("app: \(app.name)")
            //printApp(app: app, prefix: "  ")
        //}
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
        
        self.syntaxAnalyser.reset(with: pathWithoutGit)
        self.fileManager.updateDependencies(path: pathWithoutGit)
        
        var includePaths: [String] = fileManager.fetchAllFiles(folderPath: pathWithoutGit).map() { url in return url.path}
        //print("all include paths: \(includePaths)")
        
        var isMerge = false
        if appVersion.parent != nil && appVersion.alternateParent != nil {
            isMerge = true
        }
        
        var newClassVersions: [Class] = []
        
        if !self.noSourceCodeAnalysis {
            if let parent = appVersion.parent {
                print("has parent")
                if let parentApp = appVersion.parent?.appVersion.analysedVersion {
                    
                    let parentClasses = parentApp.classes
                    var altParentClasses: [Class] = []
                    
                    var intersectionChanged = [String]()
                    var intersectionParentNew = [String]()
                    var instersectonAltParentNew = parent.changedPaths
                    var intersectionNew = parent.addedPaths
                    
                    //print("parent: ")
                    //print("chagned: \(parent.changedPaths)")
                    //print("new: \(parent.addedPaths)")
                    //print("unchanged: \(parent.unchangedPaths)")
                    
                    if let altParent = appVersion.alternateParent {
                        print("has alt parent")
                        //print("altparent: ")
                        //print("chagned: \(altParent.changedPaths)")
                        //print("new: \(altParent.addedPaths)")
                        //print("unchanged: \(altParent.unchangedPaths)")
                        
                        if let altParentApp = altParent.appVersion.analysedVersion {
                            altParentClasses = altParentApp.classes
                            //print("altParentClasses: \(altParentClasses.map(){value in return value.name})")
                            
                            for classInstance in altParentClasses {
                                //print("class: \(classInstance.name)")
                                //print("methds: \(classInstance.methods.map() {value in return value.name})")
                            }
                        } else {
                            //print("Alternate parent not analysed!")
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
                    
                    //print("combinedPaths: \(combinedPaths)")
                    
                    pathLoop: for path in combinedPaths {
                        for ignore in fileManager.ignoreWithPathComponents {
                            if path.contains(ignore) {
                                //print("ignore path \(path), contains ignore: \(ignore)")
                                continue pathLoop
                            }
                        }
                        
                        var correctEnding = false
                        for ending in fileManager.allowedEndings {
                            if path.hasSuffix(ending) {
                                correctEnding = true
                                //print("path \(path) has correct ending \(ending)")
                                break
                            }
                        }
                        
                        if !correctEnding {
                            //print("ignore path \(path), ending not correct")
                            continue pathLoop
                        }
                        
                        let classes = self.syntaxAnalyser.analyseFile(filePath: path, includePaths: includePaths)
                        
                        var classesToAdd: [Class] = []
                        
                        for classInstance in classes {
                            if let existingClass = addedClasses[classInstance.usr] {
                                //print("Class already added: \(classInstance.name) - \(classInstance.usr)")
                                //TODO: should we add methods from newly analysed class if class is somehow declared in multiple files?
                            } else {
                                addedClasses[classInstance.usr] = classInstance
                                classesToAdd.append(classInstance)
                                classInstance.save()
                            }
                        }
                        
                        finalClasses.append(contentsOf: classesToAdd)
                        //print("add classes (combined paths) : \(classesToAdd.map() { val in return val.name } )")
                    }
                    
                    var remainingParentClasses: [String: Class] = [:]
                    var notChangedClasses: [String: Class] = [:]
                    
                    for classInstance in parentClasses {
                        if let addedClass = addedClasses[classInstance.usr] {
                            addedClass.parent = classInstance
                            addedClass.version = classInstance.version + 1
                            
                            var properties: [String: Any] = [:]
                            if let commit = appVersion.commit?.commit {
                                properties["commit"] = commit
                            }
                            
                            if let changesForPath = parent.changesForPaths[addedClass.path] {
                                let lineDifferences = findChangedLines(newClass: addedClass, oldClass: classInstance, changes: changesForPath)
                                
                                properties["added_lines"] = lineDifferences.added
                                properties["deleted_lines"] = lineDifferences.deleted
                                properties["changed_lines"] = lineDifferences.changed
                            }
                            
                            classInstance.relate(to: addedClass, type: "CLASS_CHANGED_TO", properties: properties)
                            
                        } else if parent.unchangedPaths.contains(classInstance.path) {
                            let refClasses = self.syntaxAnalyser.analyseFile(filePath: classInstance.path, includePaths: includePaths)
                            for refClass in refClasses {
                                if refClass.name == classInstance.name {
                                    if refClass.usr != classInstance.usr {
                                        print("class \(classInstance.name) usr: \(classInstance.usr) changed to \(refClass.usr)")
                                        classInstance.usr = refClass.usr
                                        classInstance.save()
                                    }

                                    /*
                                    for method in classInstance.methods {
                                        if let potMethods = refClass.potentialMethods {
                                            for refMethod in potMethods {
                                                if method.name == refMethod.name {
                                                    if method.usr != refMethod.usr {
                                                        method.usr = refMethod.usr
                                                        method.save()
                                                        print("update method usr")
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    for variable in classInstance.variables {
                                        if let potVariables = refClass.potentialVariables {
                                            for refVariable in potVariables {
                                                if refVariable.name == variable.name {
                                                    if variable.usr != refVariable.usr {
                                                        variable.usr = refVariable.usr
                                                        variable.save()
                                                        print("update variable usr")
                                                    }
                                                }
                                            }
                                        }
                                    }
 */
                                }
                            }
                            
                            finalClasses.append(classInstance)
                            //print("add classes (unchanged from parent): \(classInstance.name)")
                            notChangedClasses[classInstance.usr] = classInstance
                        } else if parent.removedPaths.contains(classInstance.path) {
                            // do nothing
                        } else {
                            //print("remainingParentClass: \(classInstance.name) - commit: \(appVersion.commit?.commit), path: \(classInstance.path)")
                            remainingParentClasses[classInstance.usr] = classInstance
                        }
                    }
                    
                    if let altParent = appVersion.alternateParent {
                        print("has alt parent")
                        for classInstance in altParentClasses {
                            if let addedClass = addedClasses[classInstance.usr] {
                                addedClass.alternateParent = classInstance
                                //addedClass.saveParent()
                                
                                
                                var properties: [String: Any] = [:]
                                if let commit = appVersion.commit?.commit {
                                    properties["commit"] = commit
                                }
                                
                                if let changesForPath = parent.changesForPaths[addedClass.path] {
                                    let lineDifferences = findChangedLines(newClass: addedClass, oldClass: classInstance, changes: changesForPath)
                                    
                                    properties["addedLines"] = lineDifferences.added
                                    properties["deletedLines"] = lineDifferences.deleted
                                    properties["changedLines"] = lineDifferences.changed
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
                                let refClasses = self.syntaxAnalyser.analyseFile(filePath: classInstance.path, includePaths: includePaths)
                                for refClass in refClasses {
                                    if refClass.name == classInstance.name {
                                        if refClass.usr != classInstance.usr {
                                            print("class \(classInstance.name) usr: \(classInstance.usr) changed to \(refClass.usr)")
                                            classInstance.usr = refClass.usr
                                            classInstance.save()
                                        }

                                        /*
                                        for method in classInstance.methods {
                                            if let potMethods = refClass.potentialMethods {
                                                for refMethod in potMethods {
                                                    if method.name == refMethod.name {
                                                        if method.usr != refMethod.usr {
                                                            method.usr = refMethod.usr
                                                            method.save()
                                                            print("update method usr")
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        for variable in classInstance.variables {
                                            if let potVariables = refClass.potentialVariables {
                                                for refVariable in potVariables {
                                                    if refVariable.name == variable.name {
                                                        if variable.usr != refVariable.usr {
                                                            variable.usr = refVariable.usr
                                                            variable.save()
                                                            print("update variable usr")
                                                        }
                                                    }
                                                }
                                            }
                                        }
 */
                                    }
                                }
                                
                                
                                if let remainingParentClass = remainingParentClasses[classInstance.usr] {
                                    finalClasses.append(classInstance)
                                    //print("add classes (unchanged from altParent): \(classInstance.name)")
                                    //print("remainingParentClass.id: \(remainingParentClass.node.id), remainingParentClass.parent.id: \(remainingParentClass.parent?.node.id), classInstance.id: \(classInstance.node.id), classInstance.parent.id: \(classInstance.parent?.node.id)")
                                    
                                    if remainingParentClass.node.id != nil && remainingParentClass.node.id != classInstance.node.id && remainingParentClass.node.id != classInstance.parent?.node.id && remainingParentClass.node.id != classInstance.alternateParent?.node.id {
                                        
                                        remainingParentClass.alternateParent = classInstance
                                        //classInstance.saveParent()
                                        
                                        var properties: [String: Any] = [:]
                                        if let commit = appVersion.commit?.commit {
                                            properties["commit"] = commit
                                        }
                                        
                                        if let changesForPath = parent.changesForPaths[classInstance.path] {
                                            let lineDifferences = findChangedLines(newClass: classInstance, oldClass: remainingParentClass, changes: changesForPath)
                                            
                                            properties["addedLines"] = lineDifferences.added
                                            properties["deletedLines"] = lineDifferences.deleted
                                            properties["changedLines"] = lineDifferences.changed
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
                                        //print("not adding new changed --> because already parent")
                                    }
                                    
                                } else if let notChangedClass = notChangedClasses[classInstance.usr] {
                                    // none were changed --> merge
                                    //finalClasses.append(notChangedClass)
                                    //print("add classes (non changed -- merge): \(notChangedClass.name)")
                                    
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
                            } else if let notChangedClass = notChangedClasses[classInstance.usr] {
                                
                                if notChangedClass.parent?.node.id != classInstance.node.id && classInstance.node.id != notChangedClass.alternateParent?.node.id {
                                    notChangedClass.alternateParent = classInstance
                                    
                                    var properties: [String: Any] = [:]
                                    if let commit = appVersion.commit?.commit {
                                        properties["commit"] = commit
                                    }
                                    
                                    if let changesForPath = parent.changesForPaths[notChangedClass.path] {
                                        let lineDifferences = findChangedLines(newClass: notChangedClass, oldClass: classInstance, changes: changesForPath)
                                        
                                        properties["addedLines"] = lineDifferences.added
                                        properties["deletedLines"] = lineDifferences.deleted
                                        properties["changedLines"] = lineDifferences.changed
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
                                
                            } else if let remainingParentClass = remainingParentClasses[classInstance.usr] {
                                //print("Found remainingParentClass: \(remainingParentClass.name) - \(remainingParentClass.usr)")
                                //fatalError("Found not handled remainingParentClass \(remainingParentClass.name) - should not happen!")
                                finalClasses.append(remainingParentClass)
                            } else {
                                //print("Class not handled: \(classInstance.name) - \(classInstance.usr)") //TODO: figure out how bad this is
                                finalClasses.append(classInstance)
                                //fatalError("Class not handled: \(classInstance.name) - \(classInstance.usr)")
                            }
                        }
                    } else {
                        print("no alt parent")
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
                                    for method in classInstance.methods {
                                        method.save()
                                    }
                                    
                                    classInstance.saveMethods()
                                    
                                    methodsToBeHandled.append(contentsOf: potMethods)
                                }
                                
                                if let potVariables = classInstance.potentialVariables {
                                    classInstance.variables = potVariables
                                    for variable in classInstance.variables {
                                        variable.save()
                                    }
                                    
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
                                //print("RemainingParentClass missing, but from edited file, assume it was removed")
                            } else {
                                //print("add from remainingParentClasses: \(remainingParentClass.name)")
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

                //print("analyse \(filesToBeAnalysed.count) paths, changes: \(appVersion.parent?.changes.count)")

                for file in filesToBeAnalysed {
                    //print("analyse file: \(file)")
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

                    ////print("Found class: \(syntaxTree.name)")
                    //TODO: figure out what to do with this class.. where should we define an app? if appVersion has no parent?

                    finalClasses.append(contentsOf: classes)
                    //print("add classes (no parent, new app): \(classes.map() { val in return val.name } )")
                }
                newClassVersions.append(contentsOf: finalClasses)
            }
        }
        
        var name: String
        let nameComponents = pathWithoutGit.split(separator: "/")
        if nameComponents.count >= 2 {
            name = "\(nameComponents[nameComponents.count - 2])/\(nameComponents[nameComponents.count - 1])"
        } else {
            name = pathWithoutGit
        }
        
        var app = App(name: name, homePath: pathWithoutGit, classes: finalClasses)
        appVersion.analysedVersion = app
        print("new app with nr of classes: \(finalClasses.count)")
        
        if let appVersionParent = appVersion.parent {
            //print("appversion has parent")
            if let parentApp = appVersionParent.appVersion.analysedVersion {
                //print("set parent for app")
                parentApp.children.append(app)
                app.parent = parentApp
                app.versionNumber = parentApp.versionNumber + 1
                //app.name = "\(app.versionNumber)"
                app.parentCommit = parentApp.commit
                
        
                var properties: [String:Int] = [:]
                /*
                properties["added_lines"] = appVersionParent.changedLines.added
                properties["removed_lines"] = appVersionParent.changedLines.removed
                properties["changed_lines"] = appVersionParent.changedLines.changed
                */
                
                parentApp.relate(to: app, type: "CHANGED_TO", properties: properties)
                
                //print("parentapp number of children: \(parentApp.children.count)")
            }
            
            if let alternateAppVersion = appVersion.alternateParent {
                if let alternateParentApp = alternateAppVersion.appVersion.analysedVersion {
                    app.alternateApp = alternateParentApp
                    app.alternateParentCommit = alternateParentApp.commit
                    
                    var properties: [String:Int] = [:]
                    /*
                    properties["added_lines"] = appVersionParent.changedLines.added
                    properties["removed_lines"] = appVersionParent.changedLines.removed
                    properties["changed_lines"] = appVersionParent.changedLines.changed
                    */
 
                    alternateParentApp.relate(to: app, type: "CHANGED_TO", properties: properties)
                }
            }
            
        } else {
            print("appversion has no parent")
            //self.appVersions.append(appVersion)
        }
        
        app.commit = appVersion.commit
        app.appKey = appVersion.appKey
        
        if(app.parent == nil) {
            print("app has no parent")
            //self.apps.append(app)
        }
        app.save()
        
        if !self.noSourceCodeAnalysis {
            for method in methodsToBeHandled {
                addCallAndUseConnectionsFrom(method: method, app: app)
                method.saveArguments()
            }
            
            addDefinitionConnectionsTo(app: app)
            
            if app.parent != nil {
                addCallAndUseConnectionsTo(methods: methodsToBeHandled, variables: variablesToBeHandled, classes: newClassVersions, app: app)
                
                if app.alternateApp != nil {
                    addCallAndUseConnectionsTo(app: app)
                }
            }
        }
        
        print("running external analysers for \(newClassVersions.map() {value in return value.name} )")
        for externalAnalyser in self.externalAnalysers {
            print("external analyser: \(externalAnalyser.readme)")
            if externalAnalyser.supportedLevel == .applicationLevel {
                externalAnalyser.analyseApp(app: app)
            } else if externalAnalyser.supportedLevel == .classLevel {
                for classInstance in newClassVersions {
                    externalAnalyser.analyseClass(classInstance: classInstance, app: app)
                }
            } else {
                print("Unsupported external analyer level \(externalAnalyser.supportedLevel)")
            }
        }
        
        print("Externalanalysers reset")
        for externalAnalyser in self.externalAnalysers {
            externalAnalyser.reset()
        }
    }
    
    func addDefinitionConnectionsTo(app: App) {
        if let appId = app.node.id {
            var transactions: [String] = []
            
            transactions.append("""
            match (a:App) where id(a) = \(appId)
            match (a)-[:APP_OWNS_CLASS]->(c:Class)
            where c.is_definition = true
            match (a)-[:APP_OWNS_CLASS]->(c2:Class)
            where c2.is_definition = false and c.usr = c2.usr
            merge (c2)-[r:DEFINED_IN]->(c) return id(r)
            """)
            
            transactions.append("""
            match (a:App) where id(a) = \(appId)
            match (a)-[:APP_OWNS_CLASS]->(c:Class)-[:CLASS_OWNS_METHOD|CLASS_OWNS_VARIABLE]->(o)
            where o.is_definition = true
            match (a)-[:APP_OWNS_CLASS]->(c:Class)-[:CLASS_OWNS_METHOD|CLASS_OWNS_VARIABLE]->(o2)
            where o2.is_definition = false and o.usr = o2.usr
            merge (o2)-[r:DEFINED_IN]->(o) return id(r)
            """)
           
            for transaction in transactions {
                print("running transaction: \(transaction)")
                DatabaseController.currentDatabase.client?.runQuery(transaction: transaction)
            }
        }
    }
    
    func handleMethodsMerge(newClass: Class, changesParent: [String: [FileChange]], changesAddParent: [String: [FileChange]]) -> [Method] {
        
        if let parent = newClass.parent, let altParent = newClass.alternateParent {
            var newMethods: [Method] = []
            var oldMethods: [Method] = []
            
            let methodsParent = findNewAndUpdatedMethods(newClass: newClass, oldClass: parent, changes: changesParent)
            
            let methodsAltParent = findNewAndUpdatedMethods(newClass: newClass, oldClass: altParent, changes: changesAddParent)
            
            var handledMethods: [String: Method] = [:]
            
            methodLoop: for method in methodsParent.new {
                for altMethod in (methodsAltParent.new + methodsAltParent.updated + methodsAltParent.old) {
                    if method.usr == altMethod.usr { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.usr] == nil {
                            newMethods.append(altMethod)
                            handledMethods[altMethod.usr] = altMethod
                            altMethod.saveParent()
                        }
                        
                        continue methodLoop
                    }
                }
            }
            
            methodLoop: for altMethod in methodsAltParent.new {
                for method in (methodsParent.new + methodsParent.updated + methodsParent.old) {
                    if method.usr == altMethod.usr { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.usr] == nil {
                            newMethods.append(method)
                            handledMethods[method.usr] = method
                            method.saveParent()
                        }
                        
                        continue methodLoop
                    }
                }
            }
            
            methodLoop: for method in methodsParent.old {
                for altMethod in (methodsAltParent.updated) {
                    if method.usr == altMethod.usr { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.usr] == nil {
                            newMethods.append(method)
                            handledMethods[method.usr] = method
                            method.altParent = altMethod.parent
                            method.saveAltParent()
                        }
                        
                        continue methodLoop
                    }
                }
                
                for altMethod in (methodsAltParent.old) {
                    if method.usr == altMethod.usr {
                        if handledMethods[method.usr] == nil {
                            oldMethods.append(method)
                            handledMethods[method.usr] = method
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
                    if method.usr == altMethod.usr { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.usr] == nil {
                            newMethods.append(altMethod)
                            handledMethods[altMethod.usr] = altMethod
                            altMethod.altParent = method.parent
                            altMethod.saveAltParent()
                        }
                        
                        continue methodLoop
                    }
                }
            }
            
            methodLoop: for method in methodsParent.updated {
                for altMethod in (methodsAltParent.updated) {
                    if method.usr == altMethod.usr { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledMethods[method.usr] == nil {
                            newMethods.append(method)
                            handledMethods[method.usr] = method
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
                        if handledVariables[variable.usr] == nil {
                            newVariables.append(altVariable)
                            handledVariables[altVariable.usr] = altVariable
                            altVariable.saveParent()
                        }
                        
                        continue variableLoop
                    }
                }
            }
            
            variableLoop: for altVariable in variablesAltParent.new {
                for variable in (variablesParent.new + variablesParent.updated + variablesParent.old) {
                    if variable.name == altVariable.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledVariables[variable.usr] == nil {
                            newVariables.append(variable)
                            handledVariables[variable.usr] = variable
                            variable.saveParent()
                        }
                        
                        continue variableLoop
                    }
                }
            }
            
            variableLoop: for variable in variablesParent.old {
                for altVariable in (variablesAltParent.updated) {
                    if variable.name == altVariable.name { //TODO: figure out if it's ok to compare names -- usr might probably not always be the same?
                        if handledVariables[variable.usr] == nil {
                            newVariables.append(variable)
                            handledVariables[variable.usr] = variable
                            variable.altParent = altVariable.parent
                            variable.saveAltParent()
                        }
                        
                        continue variableLoop
                    }
                }
                
                for altVariable in (variablesAltParent.old) {
                    if variable.name == altVariable.name {
                        if handledVariables[variable.usr] == nil {
                            oldVariables.append(variable)
                            handledVariables[variable.usr] = variable
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
                        if handledVariables[variable.usr] == nil {
                            newVariables.append(altVariable)
                            handledVariables[altVariable.usr] = altVariable
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
                        if handledVariables[variable.usr] == nil {
                            newVariables.append(variable)
                            handledVariables[variable.usr] = variable
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
        print("handleMethods start")
        
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
        
        print("handleMethods end")
        return methods.new + methods.updated
    }
    
    func relateExistingMethods(newMethods: [Method], oldMethods: [Method]) {
        methodLoop: for oldMethod in oldMethods {
            for newMethod in newMethods {
                if oldMethod.usr == newMethod.usr {
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
        print("handleVariables start")
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
        print("handleVariables end")
        
        return variables.new + variables.updated
    }
    
    func findNewAndUpdatedMethods(newClass: Class, oldClass: Class, changes: [String: [FileChange]], isAlt: Bool = false) -> (new: [Method], updated: [Method], old: [Method]) {
        var oldNames: [String] = oldClass.methods.map() { value in return value.usr}
        
        var newNames: [String] = []
        var methodsToBeHandled = newClass.methods
        
        if methodsToBeHandled.count == 0, let potentialMethods = newClass.potentialMethods {
            methodsToBeHandled = potentialMethods
        }
        newNames = methodsToBeHandled.map() { value in return value.name}

        var newMethods: [Method] = []
        var updatedMethods: [Method] = []
        var oldMethods: [Method] = []
        
        //print("method oldNames: \(oldNames)")
        //print("method newNames: \(newNames)")

        if true {
            let methods = methodsToBeHandled
            //let methods = newClass.potentialMethods {
            //print("going through potential methods")
            methodLoop: for method in methods {
                if !oldNames.contains(method.usr) {
                    //print("new method added: \(method.usr)")
                    newMethods.append(method)
                    continue methodLoop
                }
                
                if let startLine = method.startLine, let endLine = method.endLine {
                    //print("lines: \(method.startLine) - \(method.endLine)")
                    if let changesForpath = changes[newClass.path] {
                        for fileChange in changesForpath {
                            for change in fileChange.changes {
                                //print("change lines: \(change.newLines)")
                                if let newLines = change.newLines {
                                    if !(startLine < newLines.start && endLine < newLines.start) && !(startLine > (newLines.start + newLines.length) && endLine > (newLines.start + newLines.length)) {
                                        //print("match")
                                        
                                        
                                        if oldNames.contains(method.usr) {
                                            //print("old name contains method.usr")
                                            
                                        }
                                        
                                        for oldMethod in oldClass.methods {
                                            if method.usr == oldMethod.usr {
                                                if method.node.id == nil || method.node.id != oldMethod.node.id {
                                                    //print("prev. version of method found")
                                                    if isAlt {
                                                        method.altParent = oldMethod
                                                    } else {
                                                        method.parent = oldMethod
                                                    }
                                                } else {
                                                    //print("prev version of method found, but is itself")
                                                }
                                            }
                                        }
                                        
                                        updatedMethods.append(method)
                                        
                                        continue methodLoop
                                    } else {
                                        //print("no match")
                                    }
                                }
                            }
                        }
                    }
                    
                    for oldMethod in oldClass.methods {
                        if method.usr == oldMethod.usr {
                            oldMethods.append(oldMethod)
                            
//                            if method.usr != oldMethod.usr {
//                                print("update method usr")
//                                oldMethod.usr = method.usr //  update usr
//                                oldMethod.save()
//                            }
                        }
                    }
                }
            }
            
            
        }
        
        return (new: newMethods, updated: updatedMethods, oldMethods)
    }
    
    func findChangedLines(newClass: Class, oldClass: Class, changes: [FileChange]) -> (changed: Int, added: Int, deleted: Int) {
        var changed = 0
        var added = 0
        var deleted = 0
        
        print("findChangedLines")
        
        for fileChange in changes {
            for change in fileChange.changes {
                let newLines = changedLines(classInstance: newClass, lines: change.newLines)
                let oldLines = changedLines(classInstance: oldClass, lines: change.oldLines)
                
                let difference = newLines - oldLines
                
                print("difference: \(difference)")
                
                if difference > 0 {
                    changed += oldLines
                    added += difference
                } else {
                    changed += newLines
                    deleted += -1 * difference
                }
            }
        }
        print("return \((changed: changed, added: added, deleted: deleted))")
        
        return (changed: changed, added: added, deleted: deleted)
    }
    
    func changedLines(classInstance: Class, lines: (start: Int, length: Int)?) -> Int {
        var start = -1
        var end = -1
        
        if let lines = lines {
            print("changedLines, classInstance \(classInstance.name), lines: \(lines)")
            
            if lines.length == 0 {
                return 0
            }
            
            let minLine = classInstance.minMaxLineNumbers.min
            let maxLine = classInstance.minMaxLineNumbers.max
            
            print("minLine: \(minLine), maxLine: \(maxLine)")
            
            if lines.start > maxLine {
                // no match
            } else if lines.start + lines.length < minLine {
                // no match
            } else {
                if lines.start < minLine {
                    start = minLine
                } else {
                    start = lines.start
                }
                
                if lines.start + lines.length > maxLine {
                    end = maxLine
                } else {
                    end = lines.start + lines.length
                }
            }
            
            print("end: \(end), start: \(start), difference: \(end - start + 1)")
            
            return end - start + 1
        }
        
        return 0
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
        
        //print("variable oldNames: \(oldNames)")
        //print("variable newNames: \(newNames)")

        if true {
            //let variables = variablesToBeHandled {
            let variables = variablesToBeHandled
            //print("going through potential variables")
            variableLoop: for variable in variables {
                if !oldNames.contains(variable.name) {
                    //print("new variable added: \(variable.name)")
                    newVariables.append(variable)
                    continue variableLoop
                }
                
                if let startLine = variable.startLine, let endLine = variable.endLine {
                    //print("lines: \(variable.startLine) - \(variable.endLine)")
                    if let changesForpath = changes[newClass.path] {
                        for fileChange in changesForpath {
                            for change in fileChange.changes {
                                //print("change lines: \(change.newLines)")
                                if let newLines = change.newLines {
                                    if !(startLine < newLines.start && endLine < newLines.start) && !(startLine > (newLines.start + newLines.length) && endLine > (newLines.start + newLines.length)) {
                                        //print("match")
                                        
                                        
                                        if oldNames.contains(variable.name) {
                                            //print("old name contains variable.name")
                                            
                                        }
                                        
                                        for oldVariable in oldClass.variables {
                                            if variable.name == oldVariable.name {
                                                if variable.node.id == nil || variable.node.id != oldVariable.node.id {
                                                    //print("prev. version of variable found")
                                                    variable.parent = oldVariable
                                                } else {
                                                    //print("prev version of variable found, but it is itself")
                                                }
                                            }
                                        }
                                        
                                        updatedVariables.append(variable)
                                        
                                        continue variableLoop
                                    } else {
                                        //print("no match")
                                    }
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
                //print("parent: \(parent?.name)")
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
                        /*
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
                                        //print("Class \(classInstance.name) no method or variable with name \(name)")
                                    }
                                } else {
                                    //print("Instruction does not have name: \(instruction.calledUsr)")
                                }
                            } else {
                                //print("No class for usr found: \(receiverUsr)")
                            }
                        } else {
                            //print("No receiverUsr for \(usr)")
                        }
                        */
                        
                        let external = ExternalObject(usr: usr)
                        external.save()
                        externalObjects[usr] = external
                        method.relate(to: external, type: "EXTERNAL_REF")
                    }
                    //print("Usr not found (method from): \(usr)")
                }
            }
        }
    }
    
    func addCallAndUseConnectionsTo(methods: [Method], variables: [Variable], classes: [Class], app: App) {
        
        if let appId = app.node.id {
            var methodIds: [Int] = []
            for method in methods {
                if let id = method.node.id {
                    methodIds.append(id)
                }
            }
            
            var variableIds: [Int] = []
            for variable in variables {
                if let id = variable.node.id {
                    variableIds.append(id)
                }
            }
            
            var classIds: [Int] = []
            for classInstance in classes {
                if let id = classInstance.node.id {
                    classIds.append(id)
                }
            }
            
            var transactions: [String] = []
            transactions.append("""
            match (a2:App) match (a1:App) where (a1)-[:CHANGED_TO]->(a2)
            and id(a2) = \(appId)
            match (a2)-[:APP_OWNS_CLASS]->(c3:Class)<-[:CLASS_CHANGED_TO]-(c1:Class)<-[:APP_OWNS_CLASS]-(a1)
            match (c3)-[:CLASS_OWNS_METHOD]->(m3:Method)<-[:CHANGED_TO]-(m1)<-[:CLASS_OWNS_METHOD]-(c1)
            where id(m3) in \(methodIds)
            match (a2)-[:APP_OWNS_CLASS]->(c2)-[:CLASS_OWNS_METHOD]-(m2:Method) where (m2)-[:CALLS]->(m1)
            merge (m2)-[r:CALLS]->(m3) return id(r)
            """)
            
            transactions.append("""
            match (a2:App) match (a1:App) where (a1)-[:CHANGED_TO]->(a2)
            and id(a2) = \(appId)
            match (a2)-[:APP_OWNS_CLASS]->(c3:Class)<-[:CLASS_CHANGED_TO]-(c1:Class)<-[:APP_OWNS_CLASS]-(a1)
            match (c3)-[:CLASS_OWNS_VARIABLE]->(m3:Variable)<-[:CHANGED_TO]-(m1:Variable)<-[:CLASS_OWNS_VARIABLE]-(c1)
            where id(m3) in \(variableIds)
            match (a2)-[:APP_OWNS_CLASS]->(c2)-[:CLASS_OWNS_METHOD]-(m2:Method) where (m2)-[:USES]->(m1)
            merge (m2)-[r:USES]->(m3) return id(r)
            """)
            
            transactions.append("""
            match (a2:App) match (a1:App) where (a1)-[:CHANGED_TO]->(a2)
            and id(a2) = \(appId)
            match (a2)-[:APP_OWNS_CLASS]->(c3:Class)<-[:CLASS_CHANGED_TO]-(c1:Class)<-[:APP_OWNS_CLASS]-(a1)
            where id(c3) in \(classIds)
             match (a2)-[:APP_OWNS_CLASS]->(c2)-[:CLASS_OWNS_METHOD]-(m2:Method)-[rel:CLASS_REF]->(c1)
            with distinct m2, c3, rel
            merge (m2)-[r:CLASS_REF]->(c3) return id(r)
            """)
            
            for transaction in transactions {
                print("running transaction: \(transaction)")
                DatabaseController.currentDatabase.client?.runQuery(transaction: transaction)
            }
        }
    }
    
    func addCallAndUseConnectionsTo(app:App) {
        if let appId = app.node.id {
            var transactions: [String] = []
            
            transactions.append("""
            match
                (parent:App)-[:CHANGED_TO]->(app:App)<-[:CHANGED_TO]-(alt_parent:App)
            where id(app) = \(appId)
            match
                (app)-[:APP_OWNS_CLASS]->(class:Class)<-[:APP_OWNS_CLASS]-(alt_parent)
            where not (parent)-[:APP_OWNS_CLASS]->(class)
            match
                (app)-[:APP_OWNS_CLASS]->(other_class:Class)<-[:APP_OWNS_CLASS]-(parent)
            where not (alt_parent)-[:APP_OWNS_CLASS]->(other_class)
            match
                (other_class)-[:CLASS_OWNS_METHOD]-(method:Method)-[:CLASS_REF]->(prev_class:Class)-[:CLASS_CHANGED_TO*1..]->(class)
            where not (method)-[:CLASS_REF]->(class)
            and not (prev_class)-[:CHANGED_TO*1..]->()<-[:CLASS_REF]-(method)
            merge (method)-[r:CLASS_REF]->(class)
            return id(r)
            """
            )
            
            transactions.append("""
                match (other_method:Method)<-[:CALLS]-(method:Method)<-[:CLASS_OWNS_METHOD]-(:Class)<-[:APP_OWNS_CLASS]-(app:App)-[:APP_OWNS_CLASS]->(:Class)-[:CLASS_OWNS_METHOD]->(n_method:Method)
                where
                id(app) = \(appId) and
                (other_method)-[:CHANGED_TO*1..]->(n_method) and not (method)-[:CALLS]->(n_method)
                and not (other_method)-[:CHANGED_TO*1..]->()<-[:CALLS]-(method)
                merge (method)-[r:CALLS]->(n_method)
                return id(r)
                """)
            
            transactions.append("""
                match (other_variable:Variable)<-[:USES]-(method:Method)<-[:CLASS_OWNS_METHOD]-(:Class)<-[:APP_OWNS_CLASS]-(app:App)-[:APP_OWNS_CLASS]->(:Class)-[:CLASS_OWNS_VARIABLE]->(n_variable:Variable)
                where
                id(app) = \(appId) and
                (other_variable)-[:CHANGED_TO*1..]->(n_variable) and not (method)-[:USES]->(n_variable)
                and not (other_variable)-[:CHANGED_TO*1..]->()<-[:USES]-(method)
                merge (method)-[r:USES]->(n_variable)
                return id(r)
                """)
            
            for transaction in transactions {
                print("running transaction: \(transaction)")
                DatabaseController.currentDatabase.client?.runQuery(transaction: transaction)
            }
        }
    }
}
