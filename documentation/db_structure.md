# Database structure

# DB Structure

## Nodes and properties

### Variable	

* _app\_key__- unique key to identify application, will be added
* _code_ - snippet of code where given variable is defined, currently disabled, will be made optional
* __kind__ - defines if variables is instance, class or static variable
* _modifier_ - private/public/internal/fileprivate/open - will be added
* __name__ - name of variable
* __type__ - type of variable, f.ex. String, [Int]?, App 
* __usr__ - unique identifier of variable inside app (provided by SourceKit)
* __start\_line__ - starting line of variable declaration
* __end\_line__ - ending line of variable declaration
* __version\_number__ - version number of variable, showing how many times the variable was changed

### Method

* _app\_key_ - unique key to identify application, will be added
* __cyclomatic\_complexity__ - cyclomatic complexity of method
* __code__ - snippet of code where given method is defined, currently disabled, will be made optional
* _is\_getter_ - defines if method is a getter method, (not yet correctly implemented)
* _is\_setter_ - defines if method is a setter method (not yet correctly implemented)
* _is\_constructor_ - defines if method is a constructor
* __kind__ - defines if method is instance, class or static method
* __max\_nesting\_depth__ - maximal nesting depth of if/else/while/for/etc in a method -- will be added
* _max\_number\_of\_chaned\_message\_calls_ - maximal number of chained message calls, for example: test.values().findFirst().doSomething() is 3 chained message calls (not yet implemented)
* _modifier_ - modifier of method one of the following private/public/internal/fileprivate/open
* __name__ - name of method
* __number\_of\_callers__ - number of methods that call this method
* _number\_of\_declared\_locals_ - will be added
* __number\_of\_called\_methods__ - number of methods called from this method
* __number\_of\_instructions__ - number of instructions in method
* __number_of_accessed_variables__ - number of variables used by this method
* _number\_of\_parameters_ - will be added
* _number\_of\_switch\_statements_ - will be added
* __type__ - return type of function
* __usr__ - unique identifier of method inside this application
* __start\_line__ - starting line of method declaration
* __end\_line__ - ending line of method declaration
* __version\_number__ - version number of method, showing how many times the variable was changed

### Argument - will be added

* _app\_key_ - unique key to identify application
* _name_ - name of argument
* _position_ - position of argument
* _type_ - type of argument 

### App

* __app\_key__ - unique key to identify application, optional
* _category_ - app category, information taken from .json file for bulk analysis - will be added
* _developer_ - app developer, information taken from .json file for bulk analysis - will be added
* _in\_app\_store_ - specifies if app is in the app store, information taken from .json file for bulk analysis -- will be added
* _language_ - language of the application code - will be added
* __name__ - name of application, information taken from .json file for bulk analysis
* _platform_ - platform of app, currently for all swift apps set as "iOS" -- will be added
* _star_ - number of app repository stars,  information taken from .json file for bulk analysis -- will be added
* __version\_number__ - version number of method, showing how many times the variable was changed
* __commit__ - commit hash
* __tree__ - commit tree from git log
* __branch__ - branch name, calculated by finding the following merge commit and extracting branch name from commit description. Sometimes incorrect, but currently only way to include names of deleted branches
* __tag__ - tag of commit if it exists
* __time__ - time of commit
* __author__ - author of commit
* __message__ - commit message
* __parent\_commit__ - parent commit
* __alternative\_parent\_commit__ - commit of parent that was merged

### Class

* _app\_key_ - unique key to identify application -- will be added
* __code__ - source code of class
* _is\_interface_ - specifies if class is a protocol (or interface in Java) -- will be added
* __name__ - name of class
* _parent\_name_ - name of parent class - will be added
* __usr__ - unique identifier inside application
* __kind__ - class kind
* __path__ - file path where class is located
* __version\_number__ - version number of class
        
#### Added through metrics queries

* __number\_of\_attributes__ - number of attributes in class
* _number\_of\_children__- number of children class has -- will be added
* _number\_of\_comments_ - number of comments -- will be added
* _number\_of\_implemented\_interfaces_ - number of implemented interfaces -- will be added
* __number\_of\_instructions__ - number of instructions
* __number\_of\_methods__ - number of methods
* __lack\_of\_cohesion\_in\_methods__ - lack of cohesion in methods is calculated as lackOfCohesionInMethods = noOfMethodsWith\_noVariableInCommon - noOfMethodsThat\_haveVariableInCommon or 0 if previous value is negative
* _depth\_of\_inheritance_ - number of parents a class has -- will be added
* _coupling\_between\_object\_classes_ - CBO represents the number of other classes a class is coupled to. This metrics is calculated from the callgraph and it counts the reference to methods, variables or types once for each class. -- will be added
* __class\_complexity__ - class complexity, sum of all methods cyclomatic complexities

### External 

* __name__ - name of external object
* __usr__ - usr of external object

## Relationships

* App	
   * APP\_OWNS\_CLASS Class
* _Argument_ -- will be added
   * _IS\_OF\_TYPE	Class_
* Class	
   * CLASS\_OWNS\_VARIABLE	Variable
   * CLASS\_OWNS\_METHOD	Method
   * _IMPLEMENTS	Class_ - will be added
   * _EXTENDS	Class_ - will be added
* Method	
   * USES	Variable
   * CALLS	Method
   * CLASS\_REF Class 
   * EXTERNAL\_REF External
   * _METHOD\_OWNS\_ARGUMENT	Argument_ - will be added
* Variable	
   * IS\_OF\_TYPE	Class

## Relationships and nodes added through external analysers

### DuplicationAnalyser

* Class
   * DUPLICATES	Class _(i.e. some parts of the class are duplicated in the other class)_

### InsiderSecAnalyser

#### Vulnerability
* __cvss__ - common vulnerability score
* __cwe__ - vulnerability class
* __line__ - line on which vulnerability exists
* __method__ - vulnerable method called
* __description__ - description of vulnerability
* __classPath__ - path of vulnerable file
* __recommendation__ - recommendation for removing vulnerability

#### Added relationships
* Class
  * HAS_VULNERABILITY Vulnerability
* Method
  * HAS_VULNERABILITY Vulnerability 
   
