import ArgumentParser

struct Application: ParsableCommand {
    static var configuration = CommandConfiguration(
    abstract: "A tool for analysing swift applicatins.",
    // Commands can define a version for automatic '--version' support.
    version: "1.0.0",
    subcommands: [Analyse.self, Query.self],

    // A default subcommand, when provided, is automatically selected if a
    // subcommand is not given on the command line.
    defaultSubcommand: Analyse.self)
    
    struct Analyse: ParsableCommand {
        
        @Argument(help: "Path where the project folder or the folder with multiple projects is located. If doing bulk analysis and analysed projects are not in this folder their git repositories are cloned.")
        var path: String
        
        @Option(help: "Applications appKey, should be a uniqe identifier. (optional)")
        var appKey: String?
        
        @Flag(help: "Use if evolution of app should be analysed (using git).")
        var evolution: Bool = false
        
        @Option(help: "Provide path to json file if bulk of apps should be analysed at once")
        var bulkJsonPath: String?
        
        enum Language: String, ExpressibleByArgument {
            case swift, cpp
        }
        
        @Option(help: "Which language to analyse, current options: swift, cpp.")
        var language: Language = .swift
        
        mutating func run() {
            var appManager: AppManager?
            var syntaxAnalyser: SyntaxAnalyser?
            var fileManager: LocalFileManager?
            
            if language == .swift {
                syntaxAnalyser = SwiftSyntaxAnalyser()
                fileManager = SwiftFileManager()
            } else if language == .cpp {
                syntaxAnalyser = CPPSyntaxAnalyser()
                fileManager = CPPFileManager()
            }
            
            if let bulkPath = bulkJsonPath {
                if(evolution) {
                    appManager = BulkAppManager(jsonPath: bulkPath, appManager: GitManager())
                    print("bulk analysis + evolution")
                } else {
                    appManager = BulkAppManager(jsonPath: bulkPath, appManager: SimpleAppManager())
                    print("bulk analysis without evolution")
                }
            } else {
                if(evolution) {
                    appManager = GitManager(path: path)
                    print("single project analysis + evolution")
                } else {
                    appManager = SimpleAppManager(path: path)
                    print("single project analysis without evolution")
                }
            }
            
            if let appManager = appManager, let syntaxAnalyser = syntaxAnalyser, let fileManager = fileManager {
                let appAnalysisController = AppAnalysisController(appManager: appManager, syntaxAnalyser: syntaxAnalyser, fileManager: fileManager)
                
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
}

Application.main()
