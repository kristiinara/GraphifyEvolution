# Local file manager

Local file manager handles how project files are found, which file endings are allowed and which files or folders should be ignored. The following methods and variables need to be implemented

Find all files including project files and dependency files:
    
    func fetchAllFiles(folderPath: String) -> [URL]
     
Find all project files: 

    func fetchProjectFiles(folderPath: String) -> [URL]
    
Path components that should be ignored and allowed endings: 

    var ignoreWithPathComponents: [String] {get}
    var allowedEndings: [String] {get}
