# App manager

An application manager handles which app versions should be analysed. An implementation of this protocol should implement the following methods: 

This method returns the next app version that should be analysed. 
    func nextAppVersion() -> AppVersion?

This method returns a new application manager with the given path and application key. This method is used if multiple versions of the same application manager are needed.  
    func newAppManager(path: String, appKey: String?) -> AppManager
    
Currently the following application managers are implemented: 
- simple application manager
- git application manager
- bulk application manager

### Simple application manager
Analyses a single version of an application. 

### Git application manager
Analyses the evolution of an application by fetching all commits from git and creating a new app version for each commit. 

### Bulk application manager
Parses json file with app infromation. For each found application clones the repository and then hands over finding app versions to either simple app manager or git app manager. 
