# Syntax analyser

A syntax analyser is responsible for finding classes in source code. Big part of this analysis is already implemented through default methods in the protocol. The fastest way to implement a new syntax analyser is to parse the source code into a specific json format. Default method implementations in the syntax analyser protocol can then be used to find and extract classes. The following methods and variables can be implemented:

Define constants that are used to parse the json, required. 

    var constants: Kind { get }

Required method that resets the syntax analyser before it is used for the next application manager. 

    func reset()
    
Optional reset method that can be overridden if the directory path is needed. 

    func reset(with directoryPath: String)
    
Required method that is called when a file should be analysed. 

    func analyseFile(filePath: String, includePaths: [String]) -> [Class]
    
Optional method that finds a class/method/instruction/variable inside a given json. Has a default implementation, but can be overridden. 

    func parseClassFrom(json: [String:Any], path: String) -> Class?
    func parseMethodFrom(json: [String:Any]) -> Method?
    func parseInstructionFrom(json: [String: Any]) -> Instruction?
    func parseVariableFrom(json: [String:Any]) -> Variable?
    
Optional method that fetches the code for a given path. Has a default implementation. 

    func getCodeForPath(path: String) -> String?
    
## Current implementations
Currently three implementations for syntax analyse exist for the languages Swift, Java and c++.

### SwiftSyntaxAnalyser
The syntax analyser for swift uses the [SourceKittenFramework](https://github.com/jpsim/SourceKitten) to index swift files. SourceKittenFramework is a wrapper around Apple's SourceKit and makes it possible to query ASTs for swift files. 

### CPPSyntaxAnalyser
The syntax analyser for c++ calls a python script that uses clang to parse c++ files. Source code nodes returned from clang are traversed and the python script outputs a json file in a similar format to SourceKitten. The CPPSyntaxAnalyser then uses this json to find classes. 

### JavaSyntaxAnalyser
The syntax analyser for Java calls a small Java program that uses JavaParser to parse Java files. Similarly to CPPSyntaxAnalyser nodes returned from JavaParser are traversed and the Java program outputs a json file similar to SourceKittens format. 

## Issues
Todo list: 
- Free methods (i.e. methods that do not belong to a class) are currently not handled
- Class parent-child relationships are currently not handled
- Method arguments are missing
