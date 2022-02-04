//
//  CodeSmellAnalyser.swift
//  GraphifySwift
//
//  Created by Kristiina Rahkema on 15.02.2021.
//


class MetricsAnalyser: ExternalAnalyser {
    let queries: [MetricsQuery]
    let databaseController = DatabaseController.currentDatabase
    
    func analyseApp(app: App) {
        fatalError("CodeSmellAnalyser cannot analyse whole app")
    }
    
    init() {
        var queries: [MetricsQuery] = []
        
        queries.append(LackOfCoheionQuery())
        queries.append(NumberOfMethodsQuery())
        queries.append(NumberOfAttributesQuery())
        queries.append(NumberOfInstructionsQuery())
        queries.append(NumberOfAccessedVariablesQuery())
        queries.append(ClassComplexityQuery())
        queries.append(NumberOfGettersQuery())
        queries.append(NumberOfSettersQuery())
        queries.append(NumberOfConstructorsQuery())
        queries.append(NumberOfCallersQuery())
        queries.append(NumberOfCalledMethodssQuery())
        
        self.queries = queries
    }
    
    func analyseClass(classInstance: Class, app: App) {
        for query in self.queries {
            if let transaction = query.queryStringFor(classInstance: classInstance) {
                let res = databaseController.client?.runQuery(transaction: transaction)
                //print("Analysed code smell \(query.name), for \(classInstance.name), success? \(res)")
            } else {
                print("No transaction for: \(query.name), classInstance: \(classInstance.name) id: \(classInstance.id)")
            }
        }
    }
    
    func reset() {
        // do nothing
    }
    
    func checkIfSetupCorrectly() -> Bool {
        return true
    }
    
    var supportedLanguages: [Application.Analyse.Language] = [.cpp, .java, .swift]
    
    var supportedLevel: Level = .classLevel
    
    var readme: String = "Running metrics queries for each changed class, settings metrics attributes calculated on class level."
}

class CodeSmellAnalyser: ExternalAnalyser {
    let queries: [CodeSmellQuery]
    let databaseController = DatabaseController.currentDatabase
    
    func analyseApp(app: App) {
        fatalError("CodeSmellAnalyser cannot analyse whole app")
    }
    
    init() {
        var queries: [CodeSmellQuery] = []
        
        queries.append(LongMethodQuery())
        queries.append(BlobClassQuery())
        queries.append(BrainMethodQuery())
        queries.append(ComplexClassQuery())
        queries.append(CyclicDependenciesQuery())
        queries.append(DataClassQuery())
        queries.append(DivergentChangeQuery())
        queries.append(FeatureEnvyQuery())
        queries.append(GodClassQuery())
        queries.append(IgnoringLowMemoryWarningQuery())
        queries.append(InappropriateIntimacyQuery())
        queries.append(IntensiveCouplingQuery())
        queries.append(InternalDuplicationQuery())
    
        self.queries = queries
    }
    
    func analyseClass(classInstance: Class, app: App) {
        for query in self.queries {
            if let transaction = query.queryStringFor(classInstance: classInstance) {
                let res = databaseController.client?.runQuery(transaction: transaction)
                //print("Analysed code smell \(query.name), for \(classInstance.name), success? \(res)")
            } else {
                print("No transaction for: \(query.name), classInstance: \(classInstance.name) id: \(classInstance.id)")
            }
        }
    }
    
    func reset() {
        // do nothing
    }
    
    func checkIfSetupCorrectly() -> Bool {
        return true
    }
    
    var supportedLanguages: [Application.Analyse.Language] = [.cpp, .java, .swift]
    
    var supportedLevel: Level = .classLevel
    
    var readme: String = "Running code smell queries for each changed class, setting attribute if code smell is present. Thresholds are set."
}

protocol CodeSmellQuery {
    var name: String { get }
    var description: String { get }
    
    func queryStringFor(classInstance: Class) -> String?
}

class LongMethodQuery: CodeSmellQuery {
    
    let name = "LongMethod"
    var veryHighNumberOfInstructions = Metrics.veryHighNumberOfInstructionsMethod
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "MATCH (c:Class)-[r:CLASS_OWNS_METHOD]->(m:Method) WHERE id(c)=\(id) and  m.number_of_instructions > \(self.veryHighNumberOfInstructions) SET m.is_long_method = true"
        }
        return nil
    }
    
    var result: String?
    var json: [String : Any]?
    
    var description: String {
        return "Long Method code smell looks at methods where number of instructions is bigger than very high. Very high number of instructions has to be defined statistically."
    }
}

class BlobClassQuery: CodeSmellQuery {
    let name = "BlobClass"
    let veryHighLackOfCohesienInMethods = Metrics.veryHighLackOfCohesionInMethods
    let veryHighNumberOfAttributes = Metrics.veryHighNumberOfAttributes
    let veryHighNumberOfMethods = Metrics.veryHighNumberOfMethods
    
    var description = "Blob class code smell uses lackOfCohesionInMethods, NumberOfMethods and NumberOfAttributes. Code smell is present if allthese values are high. What is high needs to be determined statistically."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                MATCH (cl:Class) WHERE
                    id(cl) = \(id) AND
                    cl.lack_of_cohesion_in_methods > \(self.veryHighLackOfCohesienInMethods) AND
                    cl.number_of_methods >  \(self.veryHighNumberOfMethods) AND
                    cl.number_of_attributes > \(self.veryHighNumberOfAttributes)
                SET cl.is_blob_class = true
                """
        }
        return nil
    }
    
    
}

class BrainMethodQuery: CodeSmellQuery {
    let name = "BrainMethod"
    let highNumberOfInstructionsForClass = Metrics.veryHighNumberOfInstructionsClass
    let highCyclomaticComplexity = Metrics.highCyclomaticComplexity
    let severalMaximalNestingDepth = 3
    let manyAccessedVariables = Metrics.shorTermMemoryCap // we could calculate this as metric
    
    var description: String = "Queries methods with high cyclomatic complexity, many accessed variables and max nesting depth of at least several that belong to classes with high number of instructions. High number of instructions and high cyclomatic complexity are determined statistically. Several maximal nesting depth should be higher than 2 and 5 and many accessed variables is according to short term memory capacity 7 to 8."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
            match (class:Class)
            where id(class) = \(id)
            match (class)-[:CLASS_OWNS_METHOD]->(method:Method)
            where class.number_of_instructions > \(self.highNumberOfInstructionsForClass) and method.cyclomatic_complexity >= \(self.highCyclomaticComplexity) and method.max_nesting_depth >= \(self.severalMaximalNestingDepth) and
                method.number_of_accessed_variables > \(self.manyAccessedVariables)
            set method.is_brain_method = true
            """
        }
        return nil
    }
}

class CommentsQuery { // TODO: implement
}

class ComplexClassQuery: CodeSmellQuery {
    var name: String = "ComplexClass"
    
    var description: String = "Queries classes where class complexity is very high."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "MATCH (cl:Class) WHERE id(class) = \(id) and  cl.class_complexity > \(Metrics.veryHighClassComplexity) SET class.is_complex_class = true"
        }
        return nil
    }
    
    
}

class CyclicDependenciesQuery: CodeSmellQuery {
    var name: String = "CyclicDependencies"
    
    var description: String = "Queries if there is a cyclic (variable) dependency through a given class and sets is_cyclic_dependency to true if there is."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "match (c:Class) where id(c) = \(id) match (c)-[:CLASS_OWNS_VARIABLE]->(v:Variable)-[:IS_OF_TYPE]->(c2:Class) where c <> c2 match cyclePath=shortestPath((c2)-[:CLASS_OWNS_VARIABLE|IS_OF_TYPE*]->(c)) with c, v, [n in nodes(cyclePath) | n ] as names  set c.is_cyclic_dependency = true"
        }
        return nil
    }
}

class DataClassQuery: CodeSmellQuery {
    var name: String = "DataClass"
    
    var description: String = ""
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "match (c:Class) where id(class) = \(id) and c.number_of_methods - c.number_of_getters - c.number_of_setters - c.number_of_constructors = 0 set c.is_data_class = true"
        }
        return nil
    }
}

////TODO: implement (needs arguments)
//class DataClumpArgumentsQuery {
//
//}

////TODO: implement - class or app level?
//class DataClumpFieldsQuery: CodeSmellQuery {
//}

////TODO: implement (needs parent classes)
//class DistortedHierarchyQuery: CodeSmellQuery {
//}

class DivergentChangeQuery: CodeSmellQuery {
    var name: String = "DivergentChange"
    let veryHighNumberOfCalledMethods = Metrics.veryHighNumberOfCalledMethods
    
    var description: String = "Queries methods that call too many methods."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "return MATCH (c:Class) where id(c) = \(id) match (c)-[:CLASS_OWNS_METHOD]-> (m:Method) where m.number_of_called_methods > \(self.veryHighNumberOfCalledMethods) set m.is_divergent_change = true"
        }
        return nil
    }
}

// We do not have modules
//class ExternalDuplicationQuery: CodeSmellQuery {
//}

class FeatureEnvyQuery: CodeSmellQuery {
    var name = "FeatureEnvy"
        let fewAccessToForeignVariables = 2
        let fewAccessToForeignClasses = 2
        let localityFraction = 0.33
    
    var description: String = "Queries classes that tend to access more foreign variables than local variables."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                        MATCH (class:Class) where id(class) = \(id)
                        MATCH (class)-[:CLASS_OWNS_METHOD]->(m:Method)-[:USES]->(v:Variable)<-[:CLASS_OWNS_VARIABLE]-(other_class:Class)
                        WHERE class <> other_class
                        WITH
                            class, m,
                            count(distinct v) as variable_count,
                            collect(distinct v.name) as names,
                            collect(distinct other_class.name) as class_names,
                            count(distinct other_class) as class_count
                        MATCH (class)-[:CLASS_OWNS_METHOD]->(m)-[:USES]->(v:Variable)<-[:CLASS_OWNS_VARIABLE]-(class)
                        WITH
                            class, m, variable_count, class_names, names,
                            count(distinct v) as local_variable_count,
                            collect(distinct v.name) as local_names,
                            class_count
                        WHERE
                            local_variable_count + variable_count > 0
                        WITH
                            class, m, variable_count, class_names, names, local_variable_count, local_names, class_count,
                            local_variable_count*1.0/(local_variable_count+variable_count) as locality
                        WHERE
                        variable_count > \(self.fewAccessToForeignVariables) and locality < \(self.localityFraction) and class_count <= \(self.fewAccessToForeignClasses)
                        SET
                            class.is_feature_envy = true
                        """
        }
        return nil
    }
    
}
class GodClassQuery: CodeSmellQuery {
    let name = "GodClass"
    let fewAccessToForeignData = 2
    let veryHighClassComplexity = Metrics.veryHighClassComplexity
    let tightClassCohesionFraction = 0.3
    
    var description: String = "Query classes with a tight class cohesion of less than a third, very high number of weighted methods and at least few access to foreign data variables."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
            match (class:Class) where id(class) = \(id)
            match (class)-[:CLASS_OWNS_METHOD]->(method:Method)
            match (class)-[:CLASS_OWNS_METHOD]->(other_method:Method)
            where method <> other_method
            with count(DISTINCT [method, other_method]) as pair_count, class
            match (class)-[:CLASS_OWNS_METHOD]->(method:Method)
            match (class)-[:CLASS_OWNS_METHOD]->(other_method:Method)
            match (class)-[:CLASS_OWNS_VARIABLE]->(variable:Variable)
            where method <> other_method and (method)-[:USES]->(variable)<-[:USES]-(other_method)
            with class, pair_count, method, other_method, collect(distinct variable.name) as variable_names, count(distinct variable) as variable_count
            where variable_count >= 1
            with class, pair_count, count(distinct [method, other_method]) as connected_method_count
            with class, connected_method_count*0.1/pair_count as class_cohesion, connected_method_count, pair_count
            where class_cohesion < \(self.tightClassCohesionFraction) and class.class_complexity >= \(self.veryHighClassComplexity)
            optional match (class)-[:CLASS_OWNS_METHOD]->(m:Method)-[:USES]->(variable:Variable)<-[:CLASS_OWNS_VARIABLE]-(other_class:Class)
            where class <> other_class
            with class, class_cohesion, connected_method_count, pair_count, count(distinct variable) as foreign_variable_count
            where foreign_variable_count >= \(self.fewAccessToForeignData)
            set class.is_god_class = true
            """
        }
        return nil
    }
    
    
}
class IgnoringLowMemoryWarningQuery: CodeSmellQuery {
    var name: String = "IgnoringLowMemoryWarning"
    
    var description: String = "Queries classes that do not have the method didReceiveMemoryWarning()."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "match (class:Class) where id(class) = \(id) and class.name contains 'ViewController' and not (class)-[:CLASS_OWNS_METHOD]->(:Method{name:'didReceiveMemoryWarning()'}) return class.app_key as app_key, class.name as class_name"
        }
        else {
            return nil
        }
    }
}

class InappropriateIntimacyQuery: CodeSmellQuery {
    var name = "InappropriateIntimacy"
    let highNumberOfCallsBetweenClasses = Metrics.highNumberOfCallsBetweenClasses
    
    var description: String = "Queries class pairs where number of calls between classes is high."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
            match (class:Class) where id(class) = \(id)
            match (class)-[:CLASS_OWNS_METHOD]->(method:Method)-[r:CALLS]->(other_method:Method)<-[:CLASS_OWNS_METHOD]-(other_class:Class)
            where  class <> other_class
            with count(distinct r) as number_of_calls, collect(distinct method.name) as method_names, collect(distinct other_method.name) as other_method_names, class, other_class
            where number_of_calls > \(highNumberOfCallsBetweenClasses)
            with class, count(class)/2 as number_of_smells
            set class.has_innapropriate_intimacy = number_of_smells
        """
        }
        return nil
    }
}

class IntensiveCouplingQuery: CodeSmellQuery {
    var name: String = "IntensiveCoupling"
    let maxNumberOfShortMemoryCap = Metrics.shorTermMemoryCap
    let fewCouplingIntensity = 2
    let halfCouplingDispersion = 0.5
    let quarterCouplingDispersion = 0.25
    let shallowMaximumNestingDepth = 1
    
    var description: String = ""
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "match (c:Class) where id(c) = \(id) match (c)-[r:CLASS_OWNS_METHOD]->(m1:Method)-[s:CALLS]->(m2:Method), (c2:Class)-[r2:CLASS_OWNS_METHOD]->(m2) where id(c) <> id(c2) with c,m1, count(distinct m2) as method_count, collect(distinct m2.name) as names, collect(distinct c2.name) as class_names, count(distinct c2) as class_count  where ((method_count >= \(self.maxNumberOfShortMemoryCap) and class_count/method_count <= \(self.halfCouplingDispersion)) or (method_count >= \(self.fewCouplingIntensity) and class_count/method_count <= \(self.quarterCouplingDispersion))) and m1.max_nesting_depth >= \(self.shallowMaximumNestingDepth) set c.has_intensive_coupling = count(m1)"
        }
        return nil
    }
}

class InternalDuplicationQuery: CodeSmellQuery {
    var name: String = "InternalDuplication"
    
    var description: String = "Queries classes that duplicate or are duplicated by other classes"
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "MATCH (class:Class) where id(class) = \(id) MATCH (class)-[r:DUPLICATES]-(secondClass:Class) with class, count(distinct r) as number_of_smells SET class.is_internal_duplication = number_of_smells"
        }
        return nil
    }
}
//class LasyClassQuery: CodeSmellQuery {
//}
//class LongParameterListQuery: CodeSmellQuery {
//}
//class MassiveViewControllerQuery: CodeSmellQuery {
//}
//class MessageChainsQuery: CodeSmellQuery {
//}
//class MiddleManQuery: CodeSmellQuery {
//}
//class MissingTemplateMethodQuery: CodeSmellQuery {
//}
//class ParallelInheritanceHierarchiesQuery: CodeSmellQuery {
//}
//class PrimitiveObsessionQuery: CodeSmellQuery {
//}
//class RefusedBequestQuery: CodeSmellQuery {
//}
//class SAPBreakerQuery: CodeSmellQuery {
//}
//class ShotgunSurgeryQuery: CodeSmellQuery {
//}
//class SiblingDuplicationQuery: CodeSmellQuery {
//}
//class SpeculativeGeneralityMethodQuery: CodeSmellQuery {
//}
//class SpeculativeGeneralityProtocolQuery: CodeSmellQuery {
//}
//class SwissArmyKnifeQuery: CodeSmellQuery {
//}
//class SwitchStatementsQuery: CodeSmellQuery {
//}
//class TraditionBreakerQuery: CodeSmellQuery {
//}
//class UnstableDependenciesQuery: CodeSmellQuery {
//}


protocol MetricsQuery: CodeSmellQuery {
    
}

struct Metrics {
    /*
    static let veryHighNumberOfInstructionsMethod = 35 // from tool
    static let veryHighLackOfCohesionInMethods = 1 // metrics query
    static let veryHighNumberOfMethods = 1 // metrics query
    static let veryHighNumberOfAttributes = 1 // metrics query
    static let veryHighNumberOfInstructionsClass = 100 // metrics query
    static let highCyclomaticComplexity = 4 // from tool
    static let shorTermMemoryCap = 7 // set value
    static let veryHighClassComplexity = 3 // from tool
    static let veryHighNumberOfCalledMethods = 3 // metrics query
    static let highNumberOfCallsBetweenClasses = 2 // calculated in smell query
 */
    
    static let veryHighNumberOfAttributes = 13.5
    static let veryLowNumberOfAttributes = 0
    static let veryHighNumberOfMethods = 13.5
    static let veryLowNumberOfMethods = 0
    static let veryHighNumberOfInstructionsClass = 147.5
    static let medianNumberOfInstructionsClass = 20
    static let veryHighNumberOfComments = 29.5
    static let veryHighClassComplexity = 33.5
    static let LowComplexityMethodRatio = 1
    static let medianCouplingBetweenObjectClasses = 0
    static let veryHighNumberOfMethodsAndAttributes = 24.5
    static let lowNumberOfMethodsAndAttributes = 2
    static let veryHighLackOfCohesionInMethods = 17.5
    static let highNumberOfCallsBetweenClasses = 5
        
    // method related
    static let veryHighCyclomaticComplexity = 6
    static let highCyclomaticComplexity = 3
    static let veryHighNumberOfCalledMethods = 2.5
    static let veryHighNumberOfCallers = 2.5
    static let veryHighNumberOfInstructionsMethod = 30.5
    static let highNumberOfInstructionsMethod = 14
    static let lowNumberOfInstructionsMethod = 3
    static let veryHighNumberOfParameters = 2.5
    static let veryHighNumberOfChainedMessages = 2.5
    static let veryHighNumberOfSwitchStatements = 0 // will not work!
        
    // variable related
    static let veryHighPrimitiveVariableUse = 6
    
    // interface related
    static let veryHighNumberOfMethodsInterface = 5
        
    // other metrics
    static let shorTermMemoryCap = 7
}


/*
 separate  queries for setting metrics --> makes more sense than calculating here? 
 */


class LackOfCoheionQuery: MetricsQuery {
    var name: String = "LackOfCohesion"
    
    var description: String = "Sets lack_of_cohesion of class. Lack of cohesion is calculated by finding number of methods that use common variables and number of methods that do not use common variables and then substracting the first form the second. Minimal value is 0."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                match (class:Class) where id(class) = \(id) optional match (class)-[:CLASS_OWNS_METHOD]-> (m:Method)-[:USES]->(variable)<-[:USES]- (n:Method)<-[:CLASS_OWNS_METHOD]-(class)  where m <> n with  distinct class, m, n  with class, count(m)/2 as method_common_count optional match (class)-[:CLASS_OWNS_METHOD]-> (m:Method), (n:Method)<-[:CLASS_OWNS_METHOD]-(class) where not  (m:Method)-[:USES]->()<-[:USES]- (n:Method) with distinct class, method_common_count, m, n with class, method_common_count, count(m)/2 as method_distinct_count with class, (method_distinct_count - method_common_count) as lack_of_cohesion_in_methods set class.lack_of_cohesion_in_methods = case when lack_of_cohesion_in_methods > 0 then lack_of_cohesion_in_methods else 0 end
                """
        }
        return nil
    }
}

class NumberOfMethodsQuery: MetricsQuery {
    var name: String = "NumberOfMethods"
    
    var description: String = "Sets number_of_methods of a class."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                    match (class:Class) where id(class) = \(id) optional match (class)-[:CLASS_OWNS_METHOD]->(method:Method) with class, count(distinct method) as number_of_methods set class.number_of_methods = number_of_methods
                """
        }
        return nil
    }
}

class NumberOfAttributesQuery: MetricsQuery {
    var name: String = "NumberOfAttributes"
    
    var description: String = "Sets number_of_attributes of a class."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                    match (class:Class) where id(class) = \(id) optional match (class)-[:CLASS_OWNS_VARIABLE]->(variable:Variable) with class, count(distinct variable) as number_of_attributes set class.number_of_attributes = number_of_attributes
                """
        }
        return nil
    }
}

class NumberOfInstructionsQuery: MetricsQuery {
    var name: String = "NumberOfInstructions"
    
    var description: String = "Sets number_of_instructions for each class by adding together number_of_instructions for each method and number of variables"
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "match (class:Class) where id(class) = \(id) optional match (class)-[:CLASS_OWNS_METHOD]->(method:Method) with class, sum(method.number_of_instructions) as number_of_method_instructions optional match (class)-[:CLASS_OWNS_VARIABLE]->(variable:Variable) with class, number_of_method_instructions, count(distinct variable) as number_of_variables set class.number_of_instructions = number_of_method_instructions + number_of_variables"
        }
        return nil
    }
}

class NumberOfAccessedVariablesQuery: MetricsQuery {
    var name: String = "NumberOfAccessedVariables"
    
    var description: String = "Set number_of_accessed_variables for each method as the number of used variables."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "match (class:Class) where id(class) = \(id) match (class)-[:CLASS_OWNS_METHOD]->(method:Method) optional match (method)-[:USES]->(variable:Variable) with method, count(distinct variable) as number_of_accessed_variables set method.number_of_accessed_variables = number_of_accessed_variables"
        }
        return nil
    }
}

class ClassComplexityQuery: MetricsQuery {
    var name: String = "ClassComplexity"
    
    var description: String = "Set class_complexity as sum of method cyclomatic complexities."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "match (class:Class) where id(class) = \(id) optional match (class)-[:CLASS_OWNS_METHOD]->(method:Method) with class, sum(method.cyclomatic_complexity) as class_complexity set class.class_complexity = class_complexity"
        }
        return nil
    }
}

class NumberOfSettersQuery: MetricsQuery {
    var name: String = "NumberOfSetters"
    
    var description: String = "Set number_of_setters as count of set methods"
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                    match (class:Class) where id(class) = \(id) optional match (class)-[:CLASS_OWNS_METHOD]->(method:Method) where method.is_setter = true with class, count(distinct method) as number_of_methods set class.number_of_setters = number_of_methods
                """
        }
        return nil
    }
}

class NumberOfGettersQuery: MetricsQuery {
    var name: String = "NumberOfGetters"
    
    var description: String = "Set number_of_getters as count of get methods"
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                    match (class:Class) where id(class) = \(id) optional match (class)-[:CLASS_OWNS_METHOD]->(method:Method) where method.is_getter = true with class, count(distinct method) as number_of_methods set class.number_of_getters = number_of_methods
                """
        }
        return nil
    }
}

class NumberOfConstructorsQuery: MetricsQuery {
    var name: String = "NumberOfConstructors"
    
    var description: String = "Set number_of_constructors as count of constructor methods"
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                    match (class:Class) where id(class) = \(id) optional match (class)-[:CLASS_OWNS_METHOD]->(method:Method) where method.is_constructor = true with class, count(distinct method) as number_of_methods set class.number_of_constructors = number_of_methods
                """
        }
        return nil
    }
}

class NumberOfCalledMethodssQuery: MetricsQuery {
    var name: String = "NumberOfCalledMethods"
    
    var description: String = "Set number_of_called_methods as count of called methods"
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                    match (class:Class) where id(class) = \(id) match (class)-[:CLASS_OWNS_METHOD]->(method:Method) optional match (method)-[:CALLS]->(other:Method) with method, count(distinct other) as number_of_called_methods set method.number_of_called_methods = number_of_called_methods
                """
        }
        return nil
    }
}

class NumberOfCallersQuery: MetricsQuery {
    var name: String = "NumberOfCallers"
    
    var description: String = "Set number_of_callers as count of methods that call this method"
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return """
                    match (class:Class) where id(class) = \(id) match (class)-[:CLASS_OWNS_METHOD]->(method:Method) optional match (method)<-[:CALLS]-(other:Method) with method, count(distinct other) as number_of_callers set method.number_of_callers = number_of_callers
                """
        }
        return nil
    }
}


// Implement possibility to run custom metrics queries from settings file
//class CustomMetricsQuery: MetricsQuery {
//
//}




