//
//  DependencyAnalyser.swift
//  ArgumentParser
//
//  Created by Kristiina Rahkema on 06.08.2021.
//

import Foundation

class DependencyAnalyser: ExternalAnalyser {
    var libraryDictionary: [String: (name: String, path: String?, versions: [String:String])] = [:]
    
    func analyseClass(classInstance: Class, app: App) {
        fatalError("DependencyAnalyser does not support class level analysis")
    }
    
    func reset() {
        //
    }
    
    func checkIfSetupCorrectly() -> Bool {
        //TODO: check if cocoapods and carthage is installed
        
        return true
    }
    
    var supportedLanguages: [Application.Analyse.Language] = [.swift]
    
    var supportedLevel: Level = .applicationLevel
    
    var readme: String {
        return "Analyses dependencies of an iOS application/libarary and enters them into the database"
    }
    
    func getNameFromGitPath(path: String) -> String? {
        var libraryName: String? = nil
        if path.contains(".com") {
            libraryName = path.components(separatedBy: ".com").last!.replacingOccurrences(of: ".git", with: "")
        } else if path.contains(".org") {
            libraryName = path.components(separatedBy: ".org").last!.replacingOccurrences(of: ".git", with: "")
        }
        
        if var foundName = libraryName {
            foundName = foundName.lowercased()
            foundName.removeFirst()
            libraryName = foundName
        }
        
        return libraryName
    }
        
    func translateLibraryVersion(name: String, version: String) -> (name: String, version: String?)? {
        print("translate library name: \(name), version: \(version)")
        
       // let currentDirectory = FileManager.default.currentDirectoryPath
        let currentDirectory = "/Users/kristiina/Phd/Tools/GraphifyEvolution"
        //print("currnent directory: \(currentDirectory)")
        let specDirectory = "\(currentDirectory)/ExternalAnalysers/Specs/Specs" // TODO: check that the repo actually exists + refresh?
        //print("specpath: \(specDirectory)")
        
        if var translation = libraryDictionary[name] {
            if let translatedVersion = translation.versions[version] {
                return (name:translation.name, version: translatedVersion)
            } else {
                if let path = translation.path {
                    let enumerator = FileManager.default.enumerator(atPath: path)
                    var podSpecPath: String? = nil
                    while let filename = enumerator?.nextObject() as? String {
                        print(filename)
                        if filename.hasSuffix("podspec.json") {
                            podSpecPath = "\(path)/\(filename)"
                            print("set podspecpath: \(podSpecPath)")
                        }
                        
                        if filename.lowercased().hasPrefix("\(version)/") && filename.hasSuffix("podspec.json"){
                            var newVersion = Helper.shell(launchPath: "/usr/bin/grep", arguments: ["\"version\":", "\(path)/\(filename)"])
                            newVersion = newVersion.trimmingCharacters(in: .whitespacesAndNewlines)
                            newVersion = newVersion.replacingOccurrences(of: "\"version\": ", with: "")
                            newVersion = newVersion.replacingOccurrences(of: "\"", with: "")
                            newVersion = newVersion.replacingOccurrences(of: ",", with: "")
                            
                            var tag = Helper.shell(launchPath: "/usr/bin/grep", arguments: ["\"tag\":", "\(path)/\(filename)"])
                            tag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                            tag = tag.replacingOccurrences(of: "\"version\": ", with: "")
                            tag = tag.replacingOccurrences(of: "\"", with: "")
                            tag = tag.replacingOccurrences(of: ",", with: "")
                            
                            let gitPath = Helper.shell(launchPath: "/usr/bin/grep", arguments: ["\"git\":", "\(path)/\(filename)"])
                            
                            let libraryName = getNameFromGitPath(path: gitPath)
                            
                            if newVersion != "" && tag != "" {
                                translation.versions[version] = newVersion
                            }
                            
                            if var libraryName = libraryName {
                                libraryName = libraryName.trimmingCharacters(in: .whitespacesAndNewlines)
                                libraryName = libraryName.replacingOccurrences(of: "\"", with: "")
                                libraryName = libraryName.replacingOccurrences(of: ",", with: "")
                                
                                translation.name = libraryName
                            }
                            libraryDictionary[name] = translation
                            return (name: translation.name, version: newVersion)
                        }
                        
                        if let podSpecPath = podSpecPath {
                            print("parse podSpecPath: \(podSpecPath)")
                            var libraryName: String? = nil
                            
                            let gitPath = Helper.shell(launchPath: "/usr/bin/grep", arguments: ["\"git\":", "\(podSpecPath)"])
                            print("found gitPath: \(gitPath)")
                            
                            libraryName = getNameFromGitPath(path: gitPath)
                            
                            if var libraryName = libraryName {
                                libraryName = libraryName.trimmingCharacters(in: .whitespacesAndNewlines)
                                libraryName = libraryName.replacingOccurrences(of: "\"", with: "")
                                libraryName = libraryName.replacingOccurrences(of: ",", with: "")
                                
                                translation.name = libraryName
                                libraryDictionary[name] = translation
                                
                                return (name: translation.name, version: nil)
                            }
                        }
                    }
                } else {
                    return nil // it was a null translation for speed purposes
                }
                
                return (name: translation.name, version: nil)
            }
        } else {
            //find library in specs
            let enumerator = FileManager.default.enumerator(atPath: specDirectory)
            while let filename = enumerator?.nextObject() as? String {
                //print(filename)
                if filename.lowercased().hasSuffix("/\(name)") {
                    print("found: \(filename)")
                    libraryDictionary[name] = (name: name, path: "\(specDirectory)/\(filename)", versions: [:])
                    return translateLibraryVersion(name: name, version: version)
                }
                
                if filename.count > 7 {
                    enumerator?.skipDescendents()
                }
            }
            
            libraryDictionary[name] = (name: name, path: nil, versions: [:]) // add null translation to speed up project analysis for projects that have many dependencies that cannot be found in cocoapods
        }
        /*
         cocoaPodsName:
            ( name:
              versions:
                [cocoaPodsVersion: tag]
            )
         */
        return nil
    }
    /*
     kristiina@Kristiinas-Mac-mini afone % time SwiftDependencyChecker analyse --action dependencies
     path: /Users/kristiina/PhD/Experiments/OpenSourceApps/afone
     action: dependencies
     Dependencies:
     Indirect: cocoalumberjack/cocoalumberjack 3.5.3 - core
     cocoalumberjack/cocoalumberjack 3.5.3 - swift
     toddkramer/codablekeychain 1.0.0 (CodableKeychain)
     */
    
    func analyseApp(app: App) {
        //app.homePath
        
        let checkerPath = "/Users/kristiina/PhD/Tools/DependencyChecker/.build/release/SwiftDependencyChecker"
        //let checkerPath = "/opt/homebrew/bin/SwiftDependencyChecker"
        let res = Helper.shell(launchPath: "/bin/bash", arguments: ["-c", "\(checkerPath) analyse \(app.homePath) --action dependencies"])
        print("res: \(res)")
        
        var resultsReached = false
        let lines = res.components(separatedBy: .newlines)
        for var line in lines {
            if line.starts(with: "Dependencies:") {
                resultsReached = true
                print("reached dependencies")
                continue
            }
            print("line: \(line)")
            
            if resultsReached {
                let indirect = line.hasPrefix("Indirect:")
                line = line.replacingOccurrences(of: "Indirect:", with: "")
                line = line.trimmingCharacters(in: .whitespaces)
                
                let components = line.components(separatedBy: " ")
                if components.count < 2 {
                    continue
                }
                
                var i = 0
                
                var platform: String = ""
                if components[0].hasSuffix(":") {
                    var platformValue = components[0].replacingOccurrences(of: ":", with: "")
                    platform = platformValue
                    i = 1
                    
                    if components.count < 3 {
                        continue
                    }
                }
                
                let name = String(components[0 + i])
                let version = String(components[1 + i])
                
                var subTarget: String? = nil
                
                if components.count >= 4 {
                    if components[2] == "-" {
                        subTarget = components[3]
                    }
                }
                
                let library = Library(name: name, versionString: version)
                library.directDependency = !indirect
                library.subtarget = subTarget
                
                print("library: \(name), version: \(version)")
                
                self.saveLibrary(app: app, library: library, type: platform)
            }
            
            var dependencyFiles: [DependencyFile] = []
            dependencyFiles.append(findPodFile(homePath: app.homePath))
            dependencyFiles.append(findCarthageFile(homePath: app.homePath))
            dependencyFiles.append(findSwiftPMFile(homePath: app.homePath))
            
            for dependencyFile in dependencyFiles {
                if dependencyFile.used {
                    var libraryDefinitions: [LibraryDefinition] = []
                    if dependencyFile.type == .carthage {
                        libraryDefinitions = handleCartfileConfig(path: dependencyFile.definitionFile!)
                    } else if dependencyFile.type == .cocoapods {
                        libraryDefinitions = handlePodsFileConfig(path: dependencyFile.definitionFile!)
                    } else if dependencyFile.type == .swiftPM {
                        //TODO: implement
                    }
                    
                    print("libraryDefinitions: \(libraryDefinitions)")
                    
                    for library in libraryDefinitions {
                        addLibraryDefinition(app: app, library: library, type: dependencyFile.type)
                    }
                    
                    if !dependencyFile.resolved {
                        let _ = app.relate(to: Library(name: "missing_dependency_\(dependencyFile.type)", versionString: ""), type: "MISSING")
                        continue
                    }
                }
            }
        }
        
        /*
        
        var dependencyFiles: [DependencyFile] = []
        dependencyFiles.append(findPodFile(homePath: app.homePath))
        dependencyFiles.append(findCarthageFile(homePath: app.homePath))
        dependencyFiles.append(findSwiftPMFile(homePath: app.homePath))
        
        if let tag = app.commit?.tag { //TODO: also handle podspec?
            let library = Library(name: app.name, versionString: tag.removingCommonLeadingWhitespaceFromLines())
            let _ = app.relate(to: library, type: "IS")
        }
        
        print("dependencyFiles: \(dependencyFiles)")
        
        for dependencyFile in dependencyFiles {
            if dependencyFile.used {
                var libraryDefinitions: [LibraryDefinition] = []
                if dependencyFile.type == .carthage {
                    libraryDefinitions = handleCartfileConfig(path: dependencyFile.definitionFile!)
                } else if dependencyFile.type == .cocoapods {
                    libraryDefinitions = handlePodsFileConfig(path: dependencyFile.definitionFile!)
                } else if dependencyFile.type == .swiftPM {
                    //TODO: implement
                }
                
                print("libraryDefinitions: \(libraryDefinitions)")
                
                for library in libraryDefinitions {
                    addLibraryDefinition(app: app, library: library, type: dependencyFile.type)
                }
                
                if !dependencyFile.resolved {
                    let _ = app.relate(to: Library(name: "missing_dependency_\(dependencyFile.type)", versionString: ""), type: "MISSING")
                    continue
                }
                
                var libraries: [Library] = []
                if dependencyFile.type == .carthage {
                    libraries = handleCarthageFile(path: dependencyFile.resolvedFile!)
                } else if dependencyFile.type == .cocoapods {
                    libraries = handlePodsFile(path: dependencyFile.resolvedFile!)
                } else if dependencyFile.type == .swiftPM {
                    libraries = handleSwiftPmFile(path: dependencyFile.resolvedFile!)
                }
                
                print("libraries: \(libraries)")
                
                for library in libraries {
                    addLibrary(app: app, library: library, type: dependencyFile.type)
                }
             }
        }
         */
    }
    /*
    func addLibrary(app: App, library: Library, type: DependencyType) {
        if type == .carthage || type == .swiftPM {
            saveLibrary(app: app, library: library, type: type)
        } else {
            // translate, then save
            saveLibrary(app: app, library: library, type: type)
        }
    }
     
     */
    
    func addLibraryDefinition(app: App, library: LibraryDefinition, type: DependencyType) {
        if type == .carthage || type == .swiftPM {
            saveLibraryDefinition(app: app, library: library, type: type)
        } else {
            // translate, then save
            saveLibraryDefinition(app: app, library: library, type: type)
        }
    }
    
    func saveLibrary(app: App, library: Library, type: String) {
        var properties: [String:String] = [:]
        properties["type"] = type
        if let subtarget = library.subtarget {
            properties["subtarget"] = subtarget
        }
        
        if let directDependency = library.directDependency {
            if directDependency {
                let _ = app.relate(to: library, type: "DEPENDS_ON", properties: properties)
            } else {
                let _ = app.relate(to: library, type: "DEPENDS_ON_INDIRECTLY", properties: properties)
            }
        } else {
            let _ = app.relate(to: library, type: "DEPENDS_ON", properties: properties)
        }
    }
    
    func saveLibraryDefinition(app: App, library: LibraryDefinition, type: DependencyType) {
        var properties: [String:String] = [:]
        properties["type"] = type.rawValue
        properties["definitionType"] = library.type
        if let subtarget = library.subtarget {
            properties["subtarget"] = subtarget
        }
        
        let _ = app.relate(to: library, type: "DEPENDS_ON", properties: properties)
    }
    
    func handlePodsFileConfig(path: String) -> [LibraryDefinition] {
        print("handle carthage config")
        var libraries: [LibraryDefinition] = []
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            for var line in lines {
                line = line.trimmingCharacters(in: .whitespacesAndNewlines)
                line = line.lowercased()
                    
                if line.starts(with: "pod") {
                    let nameComponents = line.components(separatedBy: " ")
                    if nameComponents.count < 2 {
                        // pod 'LibraryName'
                        // pod 'LibraryName', 'versions'
                        continue
                    }
                    
                    // Clean library name
                    var libraryName = nameComponents[1].components(separatedBy: ",")[0].replacingOccurrences(of: ",", with: "")
                    libraryName = libraryName.replacingOccurrences(of: "'", with: "")
                    libraryName = libraryName.replacingOccurrences(of: "\"", with: "")
                    
                    libraryName = libraryName.components(separatedBy: "#")[0]
                    
                    let components = line.components(separatedBy: ",")
                    
                    var version = ""

                    if components.count > 1 {
                        var optionCompnents: [String] = []
                        var tempComponent = ""
                        
                        for component in components {
                            // handle following configurations where arrays will be split
                            //  pod 'LibraryName', :subspecs => ['subspec1', 'subspec2']
                            if component.contains("[") && !component.contains("]") {
                                tempComponent += component
                            } else {
                                if tempComponent != "" {
                                    tempComponent += component
                                    
                                    if component.contains("]") {
                                        optionCompnents.append(tempComponent)
                                        tempComponent = ""
                                    }
                                } else {
                                    optionCompnents.append(component)
                                }
                            }
                        }
                        var isFirst = true
                        
                        for var component in optionCompnents {
                            component = component.trimmingCharacters(in: .whitespacesAndNewlines)
                            if component.hasPrefix("pod") {
                                continue
                            }
                            
                            if !component.hasPrefix(":") {
                                if !isFirst {
                                    version = component
                                    break
                                }
                            }
                            isFirst = false
                            
                            if component.contains(":branch") {
                                version = component
                            } else if component.contains(":tag") {
                                version = component
                            } else if component.contains(":commit") {
                                version = component
                            }
                        }
                    }
                    
                    version = version.replacingOccurrences(of: "'", with: "")
                    
                    // library name is enough to find library
                    // version: branch, tag, commit or
                    
                    // options:
                    //  pod 'LibraryName', :git -> 'git-path'
                    //  pod 'LibraryName', :git -> 'git-path', :branch => 'branch'
                    //  pod 'LibraryName', :git -> 'git-path', :tag => 'tag'
                    //  pod 'LibraryName', :git -> 'git-path', :commit => 'commit'
                    //  pod 'LibraryName', :configurations => ['Debug', 'Beta']
                    //  pod 'LibraryName', :configurations => 'Debug'
                    //  pod 'LibraryName', :modular_headers => false
                    //  pod 'LibraryName', :source => 'path/specs.git'
                    //  pod 'LibrrayName/Subspecname'
                    //  pod 'LibraryName', :subspecs => ['subspec1', 'subspec2']
                    //  pod 'LibraryName', :testspecs => ['testspec1', 'testspec2']
                    //  pod 'LibraryName', :path => '../localpath/LibraryName'
                    //  pod 'LibraryName', :podspec => 'path/libraryName.podspec'
                    
                    // split by ","
                    // first component: pod + name --> split by " " --> second subcomponent name
                    //    if name contains "/" --> what do we do then?
                    // for each component:
                    //    if component contains [, but not ] then join with next components until [ and ] present
                    //    --> get new list of components
                    // for each component
                    //    strip whitespace
                    //    if starts with :git --> use as git path?
                    //    if starts with :branch --> set as version
                    //    if starts with :tag --> set as version
                    //    if starts with :commit --> set as version
                    //    if starts with :configuraitons --> ignore component
                    //    if starts with :modular_headers --> ignore component
                    //    if starts with :source --> ignore? could also clone this spec and find correct data for the library
                    //    if starts with :subspecs --> ignore? what do we do then?
                    //    if starts with :testspecs --> ignore
                    //    if starts with :path --> indicate, but ignore
                    //    if starts with :podspec --> currently ignore, we can download podspec and find correct library data from there
                    //    if starts with ":" --> then record, but ignore
                    //    if none of the above, then record as version number
                    // for each component: join all option names --> add them as type
                    
                    /* Version options
                     = 0.1 Version 0.1.
                     > 0.1 Any version higher than 0.1.
                     >= 0.1 Version 0.1 and any higher version.
                     < 0.1 Any version lower than 0.1.
                     <= 0.1 Version 0.1 and any lower version.
                     ~> 0.1.2
                     */
                    
                    var cleanedVersion = version.components(separatedBy: " ").last!
                    cleanedVersion = cleanedVersion.replacingOccurrences(of: "=", with: "")
                    cleanedVersion = cleanedVersion.replacingOccurrences(of: ">", with: "")
                    cleanedVersion = cleanedVersion.replacingOccurrences(of: "<", with: "")
                    cleanedVersion = cleanedVersion.replacingOccurrences(of: "~", with: "")
                    
                    var subspec: String? = nil
                    if libraryName.contains("/") {
                        var components = libraryName.split(separator: "/")
                        libraryName = String(components.removeFirst())
                        subspec = components.joined(separator: "/")
                    }
                    
                    print("translating librarydefinition name: ")
                    if let translation = translateLibraryVersion(name: libraryName, version: cleanedVersion) {
                        print("translation: \(translation)")
                        libraryName = translation.name
                        if let translatedVersion = translation.version {
                            version = version.replacingOccurrences(of: cleanedVersion, with: translatedVersion)
                        }
                    }
                    
                    let libraryDefinition = LibraryDefinition(name: libraryName, versionString: version, type: "pod")
                    libraryDefinition.subtarget = subspec
                    print("save library, name: \(libraryDefinition.name), version: \(version)")
                    
                    libraries.append(libraryDefinition)
                }
            }
            
        } catch {
            print("could not read podfile \(path)")
        }
        
        return libraries
    }
    
    func handleSwiftPmFileConfig(path: String) -> [LibraryDefinition] {
        print("handle swiftpm config")
        var libraries: [LibraryDefinition] = []
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            var dependenciesReached = false
            for var line in lines {
                line = line.trimmingCharacters(in: .whitespaces)
                if line.starts(with: "dependencies:") {
                    dependenciesReached = true
                    continue
                }
                
                if dependenciesReached {
                    if line.starts(with: ".package") {
                        // find url: , from:
                        // url:, requirement: ??
                        // url:, range:
                        // url: closed range:
                        // path: local - ignore
                        
                        line = line.replacingOccurrences(of: ".package(", with: "")
                        let parts = line.split(separator: ",")
                        
                        var url: String? = nil
                        var version: String? = nil
                        var module: String? = nil
                        var name: String? = nil
                        
                        for part in parts {
                            var partString = String(part)
                            partString = partString.trimmingCharacters(in: .whitespaces)
                            if partString.hasPrefix("url:") {
                                partString = partString.replacingOccurrences(of: "url:", with: "")
                                partString = partString.trimmingCharacters(in: .whitespaces)
                                
                                url = partString
                                name = getNameFromGitPath(path: partString)
                            } else if partString.hasPrefix("name:") {
                                partString = partString.replacingOccurrences(of: "name:", with: "")
                                partString = partString.trimmingCharacters(in: .whitespaces)
                                
                                module = partString
                            } else if partString.hasPrefix("from:") {
                                partString = partString.replacingOccurrences(of: "from:", with: "")
                                partString = partString.trimmingCharacters(in: .whitespaces)
                                
                                version = partString
                            } else if partString.hasPrefix("path:") {
                                break // ignore
                            } else {
                                partString = partString.trimmingCharacters(in: .whitespaces)
                                
                                version = partString
                            }
                        }
                        
                        if let url = url, let name = name {
                            let librarydef = LibraryDefinition(name: name, versionString: version ?? "", type: "swiftpm")
                            libraries.append(librarydef)
                        }
                    }
                    
                    if line.contains("]") {
                        break
                    }
                }
            }
        } catch {
            print("failed to read swiftpm file")
        }
        return libraries
    }
    
    func handleCartfileConfig(path: String) -> [LibraryDefinition] {
        print("handle carthage config")
        var libraries: [LibraryDefinition] = []
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            for line in lines {
                if line.starts(with: "github") || line.starts(with: "git") || line.starts(with: "binary") {
                    // binary:
                    //  - do not handle specially, just add LibraryDefinition (we do not handle these projects yet)
                    // github:
                    //  - can be either public git repo or private enterprise git repo, only handle public git repo correctly
                    // git:
                    //  - can be either public git repo or a local repo, only handle public repo correctly
                    
                    
                    var components = line.components(separatedBy: .whitespaces)
                    print("components: \(components)")
                    // components[0] = git, github
                    
                    if components.count < 2 {
                        break
                    }
                    
                    let type = components.removeFirst()
                    var name = components.removeFirst().replacingOccurrences(of: "\"", with: "")
                    if name.starts(with: "https://github.com/") && !name.hasSuffix(".json") {
                        name = name.replacingOccurrences(of: "https://github.com/", with: "")
                    } else if name.starts(with: "github.com/") && !name.hasSuffix(".json") {
                        name = name.replacingOccurrences(of: "github.com/", with: "")
                    }
                    
                    // version can be for example:
                    //  >= 2.3.1     -- version 2.3.1 or later
                    //  <= 2.3.1     -- does this exist?
                    //  ~> 2.3       -- version 2.3 or later, but less than 3
                    //  2.3.1        -- exact verson 2.3.1
                    let version = components.joined(separator: " ").replacingOccurrences(of: "\"", with: "")
                    libraries.append(LibraryDefinition(name: name, versionString: version, type: type))
                }
            }
        } catch {
            print("could not read carthage file \(path)")
        }
        
        return libraries
    }
    
    func handleCarthageFile(path: String) -> [Library] {
        print("handle carthage")
        var libraries: [Library] = []
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            for line in lines {
                let components = line.components(separatedBy: .whitespaces)
                print("components: \(components)")
                // components[0] = git, github
                
                if components.count != 3 {
                    break
                }
                
                let nameComponents = components[1].components(separatedBy: "/")
                
                var name: String
                if nameComponents.count >= 2 {
                    name = "\(nameComponents[nameComponents.count - 2])/\(nameComponents[nameComponents.count - 1])"
                } else {
                    name = components[1]
                }
                
                name = name.replacingOccurrences(of: "\"", with: "")
                
                if name.hasSuffix(".git") {
                    name = name.replacingOccurrences(of: ".git", with: "") // sometimes .git remanes behind name, must be removed
                }
                
                if name.hasPrefix("git@github.com:") {
                    name = name.replacingOccurrences(of: "git@github.com:", with: "") // for github projects, transform to regular username/projectname format
                }
                
                if name.hasPrefix("git@bitbucket.org:") { // for bitbucket projects keep bitbucket part to distinguish it
                    name = name.replacingOccurrences(of: "git@", with: "")
                    name = name.replacingOccurrences(of: ":", with: "/")
                }
                
                let version = components[2].replacingOccurrences(of: "\"", with: "")
                libraries.append(Library(name: name, versionString: version))
            }
        } catch {
            print("could not read carthage file \(path)")
        }
        
        return libraries
    }
    
    func handlePodsFile(path: String) -> [Library] {
        print("handle pods")
        var libraries: [Library] = []
        var declaredPods: [String] = []
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            print("lines: \(lines)")
            
            // at some point there was a change with intendations in
            
            var charactersBeforeDash = ""
            for line in lines {
                var chagnedLine = line
                chagnedLine = chagnedLine.trimmingCharacters(in: .whitespaces)
                
                if chagnedLine.starts(with: "PODS:") {
                    continue
                }
                
                if chagnedLine.starts(with: "-") {
                    charactersBeforeDash = line.components(separatedBy: "-")[0]
                    break
                }
                print("characters before dash: \(charactersBeforeDash)")
            }
            
            
            var reachedDependencies = false
            
            for fixedLine in lines {
                var line = fixedLine
                if line.starts(with: "DEPENDENCIES:") {
                    //break
                    reachedDependencies = true
                    continue
                }
                
                if reachedDependencies {
                    if line.starts(with: "\(charactersBeforeDash)- ") { // lines with more whitespace will be ignored
                        line = line.replacingOccurrences(of: "\(charactersBeforeDash)- ", with: "")
                        let components = line.components(separatedBy: .whitespaces)
                        var name = components[0].replacingOccurrences(of: "\"", with: "").lowercased()
                    
                        declaredPods.append(name)
                    }
                    
                    if line.trimmingCharacters(in: .whitespaces) == "" {
                        break
                    }
                    
                    if line.starts(with: "SPEC REPOS:") {
                        break
                    }
                }
            }
            
            print("declared pods: \(declaredPods)")
            
            for var line in lines {
                if line.starts(with: "DEPENDENCIES:") {
                    break
                }
                
                if line.starts(with: "PODS:") {
                    // ignore
                    continue
                }
                
                // check if direct or transitive?
                
                //line = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.starts(with: "\(charactersBeforeDash)- ") { // lines with more whitespace will be ignored
                    line = line.lowercased()
                    line = line.replacingOccurrences(of: "\(charactersBeforeDash)- ", with: "")
                    let components = line.components(separatedBy: .whitespaces)
                    
                    print("components: \(components)")
                    
                    if(components.count < 2) {
                        continue
                    }
                    
                    var name = components[0].replacingOccurrences(of: "\"", with: "").lowercased()
                    name = name.replacingOccurrences(of: "'", with: "")
                    
                    var version = String(components[1].trimmingCharacters(in: .whitespacesAndNewlines))
                    version = version.replacingOccurrences(of: ":", with: "")
                    version = version.replacingOccurrences(of: "\"", with: "")
                    version = String(version.dropLast().dropFirst())
                    //version.remove(at: version.startIndex) // remove (
                    //version.remove(at: version.endIndex) // remove )
                    
                    var direct = false
                    if declaredPods.contains(name) {
                        direct = true
                    }
                    
                    var subspec: String? = nil
                    if name.contains("/") {
                        var components = name.split(separator: "/")
                        name = String(components.removeFirst())
                        subspec = components.joined(separator: "/")
                    }
                    
                    // translate to same library names and versions as Carthage
                    if let translation = translateLibraryVersion(name: name, version: version) {
                        name = translation.name
                        if let translatedVersion = translation.version {
                            version = translatedVersion
                        }
                    }
                    
                    let library = Library(name: name, versionString: version)
                    library.directDependency = direct
                    library.subtarget = subspec
                    
                    libraries.append(library)
                    
                    print("save library, name: \(library.name), version: \(version)")
                } else {
                    // ignore
                    continue
                }
            }
        } catch {
            print("could not read pods file \(path)")
        }
        
        return libraries
    }
    
    func handleSwiftPmFile(path: String) -> [Library] {
        print("handle swiftpm")
        var libraries: [Library] = []
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let json = try JSONSerialization.jsonObject(with: data,
                                                          options: JSONSerialization.ReadingOptions.mutableContainers) as Any

            if let dictionary = json as? [String: Any] {
                if let object = dictionary["object"] as? [String: Any] {
                    if let pins = dictionary["pinds"] as? [[String: Any]] {
                        for pin in pins {
                            var name: String?
                            var version: String?
                            
                            name = pin["package"] as? String
                            
                            if let state = pin["state"] as? [String: Any] {
                                version = state["version"] as? String
                            }
                            
                            libraries.append(Library(name: name ?? "??", versionString: version ?? "??"))
                        }
                    }
                }
            }
        } catch {
            print("could not read swiftPM file \(path)")
        }
        
        return libraries
    }
    
    func findPodFile(homePath: String) -> DependencyFile {
        // find Podfile.lock
        
        /*
         PODS:
           - Alamofire (4.8.2) // we get name + version, what if multiple packages with the same name?
           - SwiftyJSON (5.0.0)

         DEPENDENCIES:
           - Alamofire
           - SwiftyJSON

         ....
         */
        
        
        
        let url = URL(fileURLWithPath: homePath)
        var definitionPath: String? = url.appendingPathComponent("Podfile").path
        var resolvedPath: String? = url.appendingPathComponent("Podfile.lock").path

        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: definitionPath!) {
            definitionPath = nil
        }
        
        if !fileManager.fileExists(atPath: resolvedPath!) {
            resolvedPath = nil
        }
        
        return DependencyFile(type: .cocoapods, file: definitionPath, resolvedFile: resolvedPath, definitionFile: definitionPath)
    }
    
    func findCarthageFile(homePath: String) -> DependencyFile {
        // find Carfile.resolved
        /*
         github "Alamofire/Alamofire" "4.7.3" // probably possible to add other kind of paths, not github? but we can start with just github --> gives us full path
         github "Quick/Nimble" "v7.1.3"
         github "Quick/Quick" "v1.3.1"
         github "SwiftyJSON/SwiftyJSON" "4.1.0"
         */
        let url = URL(fileURLWithPath: homePath)
        var definitionPath: String? = url.appendingPathComponent("Cartfile").path
        var resolvedPath: String? = url.appendingPathComponent("Cartfile.resolved").path
        
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: definitionPath!) {
            definitionPath = nil
        }
        
        if !fileManager.fileExists(atPath: resolvedPath!) {
            resolvedPath = nil
        }
        
        return DependencyFile(type: .carthage, file: definitionPath, resolvedFile: resolvedPath, definitionFile: definitionPath)
    }
    
    func findSwiftPMFile(homePath: String) -> DependencyFile{
        // Package.resolved
        /*
         {
           "object": {
             "pins": [
               {
                 "package": "Commandant", // we get package, repoURL, revision, version (more info that others!)
                 "repositoryURL": "https://github.com/Carthage/Commandant.git",
                 "state": {
                   "branch": null,
                   "revision": "2cd0210f897fe46c6ce42f52ccfa72b3bbb621a0",
                   "version": "0.16.0"
                 }
               },
            ....
            ]
          }
        }
         */
        
        let url = URL(fileURLWithPath: homePath)
        var definitionPath: String? = url.appendingPathComponent("Package.swift").path
        var resolvedPath: String? = url.appendingPathComponent("Package.resolved").path
        
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: definitionPath!) {
            definitionPath = nil
        }
        
        if !fileManager.fileExists(atPath: resolvedPath!) {
            resolvedPath = nil
        }
        
        return DependencyFile(type: .swiftPM, file: definitionPath, resolvedFile: resolvedPath, definitionFile: definitionPath)
    }
    
    enum DependencyType: String {
        case cocoapods, carthage, swiftPM
    }
    
    struct DependencyFile {
        let type: DependencyType
        let file: String?
        let resolvedFile: String?
        let definitionFile: String?
        
        var used: Bool {
            return file != nil
        }
        
        var resolved: Bool {
            return resolvedFile != nil
        }
    }
    
}

class Library {
    let name: String
    var subtarget: String?
    let versionString: String
    var directDependency: Bool? = nil
    
    init(name: String, versionString: String) {
        self.name = name.lowercased()
        self.versionString = versionString
    }
    
    var nodeSet: Node?
}

extension Library: Neo4jObject {
    typealias ObjectType = Library
    static var nodeType = "Library"
    
    var properties: [String: Any] {
        var properties: [String: Any]
        
        if let node = self.nodeSet {
            properties = node.properties
        } else {
            properties = [:]
        }
        
        properties["name"] = self.name
        properties["version"] = self.versionString
        
        return properties
    }
    
    var updatedNode: Node {
        let oldNode = self.node
        oldNode.properties = self.properties
        
        self.nodeSet = oldNode
        
        return oldNode
    }
    
    var node: Node {
        if nodeSet == nil {
            var newNode = Node(label: Self.nodeType, properties: self.properties)
            newNode = self.newNodeWithMerge(node: newNode)
            nodeSet = newNode
        }
        
        return nodeSet!
    }
}


class LibraryDefinition {
    let name: String
    let versionString: String
    let type: String
    var subtarget: String?
    
    
    init(name: String, versionString: String, type: String) {
        self.name = name.lowercased()
        self.versionString = versionString
        self.type = type
    }
    
    var nodeSet: Node?
}

extension LibraryDefinition: Neo4jObject {
    typealias ObjectType = LibraryDefinition
    static var nodeType = "LibraryDefinition"
    
    var properties: [String: Any] {
        var properties: [String: Any]
        
        if let node = self.nodeSet {
            properties = node.properties
        } else {
            properties = [:]
        }
        
        properties["name"] = self.name
        properties["version"] = self.versionString
       // properties["type"] = self.type
        
        return properties
    }
    
    var updatedNode: Node {
        let oldNode = self.node
        oldNode.properties = self.properties
        
        self.nodeSet = oldNode
        
        return oldNode
    }
    
    var node: Node {
        if nodeSet == nil {
            var newNode = Node(label: Self.nodeType, properties: self.properties)
            newNode = self.newNodeWithMerge(node: newNode)
            nodeSet = newNode
        }
        
        return nodeSet!
    }
}
