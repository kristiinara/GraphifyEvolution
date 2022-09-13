import ArgumentParser
import Foundation

struct Application: ParsableCommand {
    static var configuration = CommandConfiguration(
    abstract: "A tool for analysing swift applicatins.",
    // Commands can define a version for automatic '--version' support.
    version: "1.0.0",
    subcommands: [Analyse.self, Query.self, InsertDatabase.self],

    // A default subcommand, when provided, is automatically selected if a
    // subcommand is not given on the command line.
    defaultSubcommand: Analyse.self)
    
    struct Analyse: ParsableCommand {
        
        @Argument(help: "Path where the project folder or the folder with multiple projects is located. If doing bulk analysis and analysed projects are not in this folder their git repositories are cloned.")
        var path: String = FileManager.default.currentDirectoryPath
        
        @Option(help: "Applications appKey, should be a uniqe identifier. (optional)")
        var appKey: String?
        
        @Flag(help: "Use if evolution of app should be analysed (using git).")
        var evolution: Bool = false
        
        @Flag(help: "Use if source code should not be analysed")
        var noSourceAnalysis: Bool = false
        
        @Flag(help: "Only git tags")
        var onlyGitTags: Bool = false
        
        @Flag(help: "Only projects that are on appstore (only works with open source app json)")
        var onlyAppstore: Bool = false
        
        @Flag(help: "Only projects that are not yet in the database")
        var checkIfProjectExistis: Bool = false
        
        @Flag(help: "Do not allow making multiple neo4j requests in parallel")
        var noParallelRequests: Bool = false
        
        @Option(help: "Provide path to json file if bulk of apps should be analysed at once")
        var bulkJsonPath: String?
        
        @Option(help: "Provide starting commit if needed")
        var startCommit: String?
        
        @Option(help: "Provide neo4j username, default is 'neo4j'")
        var neo4jUsername: String = "neo4j"
        
        @Option(help: "Provide neo4j password, default is 1234")
        var neo4jPassword: String = "1234"
        
        @Option(help: "Provide neo4j hostname, default is localhost")
        var neo4jHost: String = "localhost"
        
        @Option(help: "Provide neo4j port, default is 7474")
        var neo4jPort: Int = 7474
        
        @Option(help: "Neo4j path if neo4j should be restarted after many app versions are analysed.")
        var neo4jPath: String?
        
        enum Language: String, ExpressibleByArgument {
            case swift, cpp, java
        }
        
        @Option(help: "Which language to analyse, current options: swift, cpp.")
        var language: Language = .swift
        
        enum ExternalAnalysis: String, ExpressibleByArgument {
            case duplication, insider, smells, metrics, dependencies, imports, languages
        }
        
        @Option(help: "Which external analysis should be run during analysis.")
        var externalAnalysis: [ExternalAnalysis] = []
        
        enum DependencyManagerChoice: String, ExpressibleByArgument {
            case simple, maven, gradle
        }
        
        @Option(help: "Which dependency manager should be used.")
        var dependencyManager: DependencyManagerChoice = .simple
        
        mutating func run() {
            var appManager: AppManager?
            var syntaxAnalyser: SyntaxAnalyser?
            var fileManager: LocalFileManager?
            
            DatabaseController.currentDatabase = DatabaseController(hostname: neo4jHost, port: neo4jPort, username: neo4jUsername, password: neo4jPassword)
            DatabaseController.currentDatabase.noParallelRequests = noParallelRequests
            
            if dependencyManager == .maven || dependencyManager == .gradle {
                if language != .java {
                    fatalError("Maven and Gradle dependency managers can only be used with java.")
                }
                
                syntaxAnalyser = JavaSyntaxAnalyser()
                let dManager: DependencyManager
                
                if dependencyManager == .maven {
                    dManager = MavenDependencyManager(ignore: [])
                } else {
                    dManager = GradleDependencyManager(ignore: [])
                }
                 
                fileManager = JavaFileManager(dependencyManager: dManager)
            } else {
                if language == .swift {
                    syntaxAnalyser = SwiftSyntaxAnalyser()
                    let dependencyManager = SimpleDependencyManager(ignore: ["/Carthage/"])
                    fileManager = SwiftFileManager(dependencyManager: dependencyManager)
                } else if language == .cpp {
                    syntaxAnalyser = CPPSyntaxAnalyser()
                    let dependencyManager = SimpleDependencyManager(ignore: [])
                    fileManager = CPPFileManager(dependencyManager: dependencyManager)
                } else if language == .java {
                    syntaxAnalyser = JavaSyntaxAnalyser()
                    let dependencyManager = SimpleDependencyManager(ignore: [])
                    fileManager = JavaFileManager(dependencyManager: dependencyManager)
                }
            }
            
            var externalAnalysers: [ExternalAnalyser] = []
            for value in externalAnalysis {
                if value == .duplication {
                    externalAnalysers.append(DuplicationAnalyser())
                } else if value == .insider {
                    externalAnalysers.append(InsiderSecAnalysis(language: language))
                } else if value == .smells {
                    externalAnalysers.append(MetricsAnalyser()) // needs to run before code smell analysis
                    externalAnalysers.append(CodeSmellAnalyser())
                } else if value == .metrics {
                    if !externalAnalysis.contains(.smells) {
                        externalAnalysers.append(MetricsAnalyser())
                    }
                } else if value == .dependencies {
                    externalAnalysers.append(DependencyAnalyser())
                } else if value == .imports {
                    if noSourceAnalysis {
                        externalAnalysers.append(ImportAnalyser())
                    } else {
                        externalAnalysers.append(ImportAnalyserClass())
                    }
                } else if value == .languages {
                    externalAnalysers.append(LanguageAnayser())
                }
            }
            
            if let bulkPath = bulkJsonPath {
                if(evolution) {
                    let gitManager = GitManager()
                    gitManager.onlyTags = onlyGitTags
                    gitManager.neo4jPath = neo4jPath
                    
                    let bulkManager = BulkAppManager(folderPath: path, jsonPath: bulkPath, appManager: gitManager)
                    bulkManager.onlyAppStore = onlyAppstore
                    bulkManager.checkIfProjectExistis = checkIfProjectExistis
                    appManager = bulkManager
                    print("bulk analysis + evolution")
                } else {
                    let bulkManager  = BulkAppManager(folderPath: path, jsonPath: bulkPath, appManager: SimpleAppManager())
                    bulkManager.onlyAppStore = onlyAppstore
                    bulkManager.checkIfProjectExistis = checkIfProjectExistis
                    appManager = bulkManager
                    print("bulk analysis without evolution")
                }
            } else {
                if(evolution) {
                    let gitManager = GitManager(path: path, appKey: appKey)
                    gitManager.onlyTags = onlyGitTags
                    gitManager.neo4jPath = neo4jPath
                    
                    if let startCommit = startCommit {
                        gitManager.startCommit = startCommit
                    }
                    appManager = gitManager
                    
                    print("single project analysis + evolution")
                } else {
                    appManager = SimpleAppManager(path: path, appKey: appKey)
                    print("single project analysis without evolution")
                }
            }
            
            if let appManager = appManager, let syntaxAnalyser = syntaxAnalyser, let fileManager = fileManager {
                let appAnalysisController = AppAnalysisController(appManager: appManager, syntaxAnalyser: syntaxAnalyser, fileManager: fileManager, externalAnalysers: externalAnalysers)
                appAnalysisController.noSourceCodeAnalysis = noSourceAnalysis
                
                appAnalysisController.runAnalysis()
            } else {
                fatalError("Appmanager, syntaxAnalyser or fileManager not defined")
            }
        }
    }
    
    struct Query: ParsableCommand {
        enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
            case html, csv
        }
        
        @Option(help: "Query that should be run to find code smells.")
        var query: String = "all"
        
        @Option(help: "Desired output format, can be either html or csv.")
        var outputFormat: OutputFormat = .csv
        
        @Option(help: "Optionally provide appKey if only one specific app should be queried.")
        var appKey: String?
        
        @Option(help: "Provide output path for html or csv files.")
        var outputPath: String = "outputFolder/"
    }
    
    struct InsertDatabase: ParsableCommand {
        @Argument(help: "Path of file to read and enter into db.")
        var path: String = FileManager.default.currentDirectoryPath
        
        enum DataClass: String, ExpressibleByArgument {
            case vulnerability, cpe
        }
        
        @Option(help: "Class of data to read and enter")
        var dataClass: DataClass = .vulnerability
        
        mutating func run() {
            switch dataClass {
            case .vulnerability:
                print("Enering vulnerabilities")
                let analyser = VulnerabilityAnalyser()
                analyser.insertVulnerabilitiesFrom(path: path)
            case .cpe:
                print("Entering cpes:")
                let analyser = VulnerabilityAnalyser()
                analyser.addCPEValuesFrom(path: path)
            }
        }
    }
}

Application.main()
