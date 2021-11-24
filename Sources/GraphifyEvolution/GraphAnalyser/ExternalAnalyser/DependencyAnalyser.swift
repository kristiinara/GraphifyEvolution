//
//  DependencyAnalyser.swift
//  ArgumentParser
//
//  Created by Kristiina Rahkema on 06.08.2021.
//

import Foundation

class DependencyAnalyser: ExternalAnalyser {
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
    
    func analyseApp(app: App) {
        //app.homePath
        
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
                    //TODO: implement
                } else if dependencyFile.type == .swiftPM {
                    //TODO: implement
                }
                
                print("libraryDefinitions: \(libraryDefinitions)")
                
                for library in libraryDefinitions {
                    let _ = app.relate(to: library, type: "DEPENDS_ON", properties: ["type": dependencyFile.type, "definitionType": library.type])
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
                    let _ = app.relate(to: library, type: "DEPENDS_ON", properties: ["type": dependencyFile.type])
                }
             }
        }
    }
    
    func handleCartfileConfig(path: String) -> [LibraryDefinition] {
        print("handle carthage config")
        var libraries: [LibraryDefinition] = []
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            for line in lines {
                if line.starts(with: "github") || line.starts(with: "git") || line.starts(with: "binary") {
                    var components = line.components(separatedBy: .whitespaces)
                    print("components: \(components)")
                    // components[0] = git, github
                    
                    if components.count < 2 {
                        break
                    }
                    
                    let type = components.removeFirst()
                    let name = components.removeFirst().replacingOccurrences(of: "\"", with: "")
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
        do {
            let data = try String(contentsOfFile: path, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            for var line in lines {
                if line.starts(with: "DEPENDENCIES:") {
                    break
                }
                
                if line.starts(with: "PODS:") {
                    // ignore
                    continue
                }
                
                // check if direct or transitive?
                
                line = line.replacingOccurrences(of: "  - ", with: "")
                let components = line.components(separatedBy: .whitespaces)
                
                print("components: \(components)")
                
                if(components.count != 2) {
                    break
                }
                
                let name = components[0]
                var version = String(components[1].dropLast().dropFirst())
                //version.remove(at: version.startIndex) // remove (
                //version.remove(at: version.endIndex) // remove )
                
                libraries.append(Library(name: name, versionString: version))
                
                print("added library")
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
    let versionString: String
    
    
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
