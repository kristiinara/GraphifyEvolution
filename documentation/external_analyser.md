# External analyser

External analysers are run after each app version analysed. The idea behind external analysers is that it is easy to add new analysers by creating a class that implements ExternalAnalyser and adding a new option for external analysers in the Main class. 

The following variables need to be implemented to specify which languages are supported by the given external analyser and if the analyser supports class or application level analysis. Class level analysis makes sense when analysis does not have to be run on all classes or if new relationships should be only added to new classes. 

    var supportedLanguages: [Application.Analyse.Language] { get }
    var supportedLevel: Level { get }
    var readme: String { get }

The following needs to be implemented, but analyseApp is only called if the supportedLevel is .app and analyseClass is only called if the supportedLevel is .class.

    func analyseApp(app:App)
    func analyseClass(classInstance:Class, app:App)
    func reset()
    func checkIfSetupCorrectly() -> Bool
    
Currenlty four external analysers are implemented: DuplicationAnalyser, InsiderSecAnalyser, MetricsAnalyser, CodeSmellAnalyser. 

## DuplicationAnalyser
Duplication analyser runs [jscpd](https://github.com/kucherenko/jscpd) to find similarities between source code files. It calls jscpd and parses the json output file to find duplications between files. This analysis is done once per app version. 
The analyser is called for each new class, if this class has a duplication to a second class the relationship DUPLICATES is added between them.
Although all files need to be passed to jscpd the analyser is implemented as a class level analyser. This way the DUPLICATES relationship is only added to new classes and there is no need to check if the relationship was already added. 

## InsiderSecAnalyser
Insider security analyser runs [insider](https://github.com/insidersec/insider) to find potential vulnerabilities in the source code. It calls insider and parses the json output file to find potential vulnerabilties. This analysis is done once per app version.
The analyser is called for each new class, if this class has a vulnerability then the HAS_VULNERABILITY relationship is added from this class to the vulnerability. If this vulnerability does not yet exist in the database it is automatically added. 
Vulnerabilities are added in such a way (merged) that if two classes or even classes from different applications have the same exact vulnerability then the HAS_VULNERABILITY relationship will point to the same common vulnerability. 

## MetricsAnalyser
Metrics analyser runs class level metrics queries for each new class. These metrics are then saved as properties of the class. The following metrics are currently calculated: LackOfCohesion, NumberOfMethods, NumberOfAttributes, NumberOfInstructions, NumberOfAccessedVariables, ClassComplexity, NumberOfGetters, NumberOfSetters, NumberOfConstructors, NumberOfCallers, NumberOfCalledMethods.

## CodeSmellAnalyser
