# Developer guide

GraphifySwiftEvolution is build in a modular manner. 

Support for new languages can be added by implementing [SyntaxAnalyser](syntax_analyser.md). Currently languages swift, java and c++ are supported. 

Support for new application managers can be added by implementing [ApplicationManager](application_manager.md). Currently managers for bulk analysis, evolution analysis and single application analysis are implemented. 

Support for new external analysers can be added by implementing [ExternalAnalyser](external_analyser.md). Currently analysers for metrics, code smells, duplication and insider (vulnerability analysis) are implemented. 

Adding or improving support for new languages, application managers and external analysers is welcomed. 
