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
        var queries: [CodeSmellQuery] = [LongMethodQuery(), BlobClassQuery(), BrainMethodQuery(), ComplexClassQuery(), CyclicDependenciesQuery(), DataClassQuery(), DistortedHierarchyQuery(), DivergentChangeQuery(), FeatureEnvyQuery(), GodClassQuery(), IgnoringLowMemoryWarningQuery(), InappropriateIntimacyQuery(), IntensiveCouplingQuery(), InternalDuplicationQuery(), LazyClassQuery(), LongParameterListQuery(), MassiveViewControllerQuery(), LongMessageChainsQuery(), MiddleManQuery(), MissingTemplateMethodQuery(), ParallelInheritanceHierarchiesQuery(), SAPBreakerQuery(), ShotgunSurgeryQuery(), SiblingDuplicationQuery(), SpeculativeGeneralityProtocolQuery(), SwissArmyKnifeQuery(), TraditionBreakerQuery()]
    
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

class DistortedHierarchyQuery: CodeSmellQuery {
    var name: String = "DistortedHierarchy"
    let shortTermMemoryCap = Metrics.shorTermMemoryCap
    
    var description: String = "Queries methods that call too many methods."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return
            """
            return MATCH (c:Class) where id(c) = \(id)
            MATCH path = (c)-[:EXTENDS*]->()
            where length(path) > ( 1 + \(shortTermMemoryCap))
            SET c.is_distorted_hierarchy = TRUE
            """
        }
        return nil
    }
}

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
class LazyClassQuery: CodeSmellQuery {
    var name: String = "LazyClass"
    let mediumNumberOfInstructions = Metrics.medianNumberOfInstructionsClass
    let lowComplexityMethodRatio = Metrics.LowComplexityMethodRatio
    let mediumCouplingBetweenObjectClasses = Metrics.medianCouplingBetweenObjectClasses
    let numberOfSomeDepthOfInheritance = 1
    
    var description: String = "Queries lazy classes that either have no methods, have low class complexity to method ratio or that have low coupling but where there is some depth of inheritance."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "MATCH (class:Class) where id(class) = \(id) and c.number_of_methods = 0 OR (c.number_of_instructions < \(mediumNumberOfInstructions) AND c.class_complexity/c.number_of_methods <= \(lowComplexityMethodRatio) OR (c.coupling_between_object_classes < \(mediumCouplingBetweenObjectClasses) AND c.depth_of_inheritance > \(numberOfSomeDepthOfInheritance) set class.is_lazy_class = TRUE"
        }
        return nil
    }
}


class LongParameterListQuery: CodeSmellQuery {
    var name: String = "LongParameterList"
    let veryHighNumberOfParameters = Metrics.veryHighNumberOfParameters
    
    var description: String = "Queries lazy classes that either have no methods, have low class complexity to method ratio or that have low coupling but where there is some depth of inheritance."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "MATCH (class:Class)-[:CLASS_OWNS_METHOD]->(m:Method) where id(class) = \(id) with class, m, size(split(m.name, ':')) -1 as argument_count where argument_count > \(veryHighNumberOfParameters) set m.is_long_parameter_list = TRUE"
        }
        return nil
    }
}


class MassiveViewControllerQuery: CodeSmellQuery {
    var name: String = "MassiveViewController"
    let veryHighNumberOfMethods = Metrics.veryHighNumberOfMethods
    let veryHighNumberOfAttributes = Metrics.veryHighNumberOfAttributes
    let veryHighNumberOfInstructions = Metrics.veryHighNumberOfInstructionsClass
    
    var description: String = "Queries lazy classes that either have no methods, have low class complexity to method ratio or that have low coupling but where there is some depth of inheritance."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "MATCH (class:Class)-[:CLASS_OWNS_METHOD]->(m:Method) where id(class) = \(id) and class.name contains 'ViewController' and class.number_of_methods > \(veryHighNumberOfMethods) and class.number_of_attributes > \(veryHighNumberOfAttributes) and class.number_of_instructions > \(veryHighNumberOfInstructions) set class.is_massive_view_controller = TRUE"
        }
        return nil
    }
}


class LongMessageChainsQuery: CodeSmellQuery {
    var name: String = "LongMessageChain"
    let veryHighNumberOfChainedMessages = Metrics.veryHighNumberOfChainedMessages
    
    var description: String = "Queries all methods, where the maximum number of chained message calls is larger than very high."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "MATCH (class:Class)-[:CLASS_OWNS_METHOD]->(m:Method) where id(class) = \(id) and m.max_number_of_chaned_message_calls > \(veryHighNumberOfChainedMessages) set m.is_long_message_chain = TRUE"
        }
        return nil
    }
}


class MiddleManQuery: CodeSmellQuery {
    var name: String = "MiddleMan"
    let lowNumberOfInstructionsMethod = Metrics.lowNumberOfInstructionsMethod
    let delegationToAllMethodsRatioHalf = 0.5
    
    var description: String = "Querying all classes where more than half of the methods are delegation methods. Delegation methods are methods that have at least one reference (uses/calles) to another class but have less than a small number of lines"
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return
            """
            MATCH (class:Class) id(class) = \(id) and
            
            (class)-[:CLASS_OWNS_METHOD]->(method:Method)-[:USES|CALLS]->(ref)<-[:CLASS_OWNS_VARIABLE|CLASS_OWNS_METHOD]-(other_class:Class)
        WHERE
            class <> other_class and
            method.number_of_instructions < \(lowNumberOfInstructionsMethod)
        WITH
            class,
            method,
            collect(ref.name) as referenced_names,
            collect(other_class.name) as class_names
        WITH
            collect(method.name) as method_names,
            collect(referenced_names) as references,
            collect(class_names) as classes,
            collect(method.number_of_instructions) as
            numbers_of_instructions,
            class,
            count(method) as method_count,
            count(method)*1.0/class.number_of_methods as method_ratio
        WHERE
            method_ratio > \(delegationToAllMethodsRatioHalf)

        SET
            class.is_middle_man = TRUE
"""
        }
        return nil
    }
}

class MissingTemplateMethodQuery: CodeSmellQuery {
    var name: String = "MissingTemplateMethod"
    let minimalCommonMethodAndVariableCount = 5
    let minimalMethodCount = 2
    
    var description: String = "Queries methods that call the same methods and use the same variables. Number of common methods and common variables should be at least minimalCommonMethodAndVariableCount. Number of methods having these variables and methods in common should be at least minimalMethodCount."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return
             """
            "MATCH (class:Class)-[:CLASS_OWNS_METHOD]->(m:Method) where id(class) = \(id)
             MATCH
                 (class)
                     -[:CLASS_OWNS_METHOD]->(method:Method)-[:USES|:CALLS]->(common)
                     <-[:USES|:CALLS]-(other_method)<-[:CLASS_OWNS_METHOD]-(other_class:Class)
             WHERE
                 method <> other_method
             WITH
                 collect(distinct common) as commons,
                 count(distinct common) as common_count,
                  class, other_class, method, other_method
             WHERE
                  common_count >= \(minimalCommonMethodAndVariableCount)
             WITH
                 [common in commons | class.name+"."+common.name] as common_names,
                 class,
                 other_class,
                 method,
                 other_method,
                 common_count
             with
                  collect(class.name) as class_names,
                 collect(class.name + "." + method.name + '-' + other_class.name + '.' + other_method.name) as method_names,
                  count(distinct method) as method_count,
                  class.name as app_key,
                 common_names, common_count,
                 collect(distinct method) as methods
              where
                             method_count >= \(minimalMethodCount)
             unwind methods as method
             set m.is_missing_template_method = TRUE
"""
        }
        return nil
    }
}


class ParallelInheritanceHierarchiesQuery: CodeSmellQuery {
    var name: String = "ParallelInheritanceHierachie"
    let minimumNumberOfClassesInHierarchy = 5
    let prefixLength = 3
    
    var description: String = "Queries parallel hierarchy trees for classes that start with the same prefixes. Prefix length currently set to 3, minimumNumberOfClassesInHierarchy set to 5."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return
"""
            "MATCH (parent:Class) where id(parent) = \(id)
             MATCH
                 (parent)<-[:APP_OWNS_CLASS]-(app:App)
             MATCH
                 (app)-[:APP_OWNS_CLASS]->(other_parent:Class)
             WHERE
                 parent <> other_parent
             MATCH
                 path = (class:Class)-[:EXTENDS*]->(parent)
             MATCH
                 other_path = (other_class:Class)-[:EXTENDS*]->(other_parent)
             WHERE
                 length(path) = length(other_path) and
                 length(path) > 0 and
                 class.name starts with substring(other_class.name, 0, \(prefixLength))
                 and parent.name starts with substring(other_parent.name, 0, \(prefixLength))
             WITH
                 collect(distinct [n in nodes(path) | n.name ]) as first,
                 collect(distinct [n in nodes(other_path) | n.name]) as second,
                 parent,
                 other_parent
             WITH
                 REDUCE(output = [], r IN first | output + r) as first_names,
                 REDUCE(output = [], r IN second | output + r) AS second_names,
                 parent,
                 other_parent
             UNWIND
                 first_names as first_name
             WITH
                 collect(distinct first_name) as first_names,
                 second_names,
                 parent,
                 other_parent
             UNWIND
                 second_names as second_name
             WITH
                 collect(distinct second_name) as second_names,
                 first_names,
                 parent,
                 other_parent
             WHERE
                 size(first_names) >= \(minimumNumberOfClassesInHierarchy) and
                 size(second_names) >= \(minimumNumberOfClassesInHierarchy)
             SET parent.is_parent_of_parallel_inheritance_tree = TRUE
"""
        }
        return nil
    }
}

// TODO: implement, variable types not added correctly
//class PrimitiveObsessionQuery: CodeSmellQuery {
//}

// not applicable to Swift
//class RefusedBequestQuery: CodeSmellQuery {
//}


class SAPBreakerQuery: CodeSmellQuery {
    var name: String = "SAPBreaker"
    let allowedDistanceFromMain = 0.5
    
    var description: String = "Queries classes where class abstractness + instability is far from the 1-x mainline. AllowedDistanceFromMain is currently set to 0.5."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return
            """
            MATCH (class:Class)-[:CLASS_OWNS_METHOD]->(m:Method) where id(class) = \(id)
            MATCH
                (app:App)-[:APP_OWNS_CLASS]->(class)
            MATCH
                (app:App)-[:APP_OWNS_CLASS]->(other_class:Class)
            WHERE
                (other_class)-[:CLASS_OWNS_METHOD]->()-[:USES|:CALLS]->()
                        <-[:CLASS_OWNS_METHOD|:CLASS_OWNS_VARIABLE]-(class) and
                class <> other_class
            WITH
                count(distinct other_class) as number_of_dependant_classes,
                class,
                app
            WITH
                class,
                number_of_dependant_classes as efferent_coupling_number,
                app

            MATCH
                (app)-[:APP_OWNS_MODULE]->(module:Module)-[:MODULE_OWNS_CLASS]->(other_class:Class)
            WHERE
                (class)-[:CLASS_OWNS_METHOD]->()-[:USES|:CALLS]->()
                        <-[:CLASS_OWNS_METHOD|:CLASS_OWNS_VARIABLE]-(other_class) and
                class <> other_class
            WITH
                count(distinct other_class) as afferent_coupling_number,
                class,
                efferent_coupling_number
            WITH
                efferent_coupling_number*1.0/(efferent_coupling_number + afferent_coupling_number) as instability_number,
                class,
                afferent_coupling_number,
                efferent_coupling_number

            OPTIONAL MATCH
                (class)-[:CLASS_OWNS_METHOD]->(method:Method)
            WHERE
                method.is_abstract
            WITH
                count(distinct method)/class.number_of_methods as abstractness_number,
                instability_number,
                afferent_coupling_number,
                efferent_coupling_number,
                class
            WITH
                1 - (abstractness_number + instability_number)^2 as difference_from_main,
                instability_number,
                abstractness_number,
                class

            WHERE
                difference_from_main < -\(allowedDistanceFromMain) or
                difference_from_main > \(allowedDistanceFromMain)
                
            SET class.is_sap_breaker = TRUE
            """
        }
        return nil
    }
}

class ShotgunSurgeryQuery: CodeSmellQuery {
    var name: String = "ShotgunSurgery"
    let veryHighNumberOfCallers = Metrics.veryHighNumberOfCallers
    
    var description: String = "Queries all methods that are called by more than a very high number of callers"
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return
            """
            MATCH (class:Class)-[:CLASS_OWNS_METHOD]->(m:Method) where id(class) = \(id)
            MATCH (other_m:Method)-[r:CALLS]->(m:Method)<-[:CLASS_OWNS_METHOD]-(class)
            WITH
                class,
                m,
                COUNT(r) as number_of_callers
            WHERE number_of_callers > \(veryHighNumberOfCallers)
            SET m.is_shotgun_surgery = TRUE
            """
        }
        return nil
    }
}

class SiblingDuplicationQuery: CodeSmellQuery {
    var name: String = "SiblingDuplication"
    
    var description: String = "Query classes that have a common parent class (somewhere in the hierarchy) and that share duplicated code."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return "MATCH (firstClass:Class) where id(firstClass) = \(id) MATCH  (firstClass:Class)-[:EXTENDS*]-> (parent:Class)<-[:EXTENDS*]-(secondClass:Class), (firstClass)-[r:DUPLICATES]-(secondClass:Class) with firstClass, count(distinct r) as number_of_smells SET firstClass.is_sibling_duplication = number_of_smells"
        }
        return nil
    }
}

class SpeculativeGeneralityProtocolQuery: CodeSmellQuery {
    var name: String = "SpeculativeGeneralityProtocol"
    
    var description: String = "Query interfaces that are not implemented or extended."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return
            """
            MATCH (class:Class) where id(class) = \(id)
             WHERE NOT
                 ()-[:IMPLEMENTS|EXTENDS]->(class) and
                 class.kind = "protocolType"
             SET class.is_speculative_generality = TRUE
            """
        }
        return nil
    }
}


//TODO: implement, needs arguments
//class SpeculativeGeneralityMethodQuery: CodeSmellQuery {
//}

class SwissArmyKnifeQuery: CodeSmellQuery {
    var name: String = "SwissArmyKnife"
    let veryHighNumberOfMethods = Metrics.veryHighNumberOfMethodsInterface
    
    var description: String = "Queries classes that are interfaces (i.e. protocols) that have a very high number of methods."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return
            """
            MATCH (cl:Class) where id(cl) = \(id)
            AND
                 cl.kind = "protocolKind" AND
                 cl.number_of_methods > \(veryHighNumberOfMethods)
            SET cl.is_swiss_army_knife
            """
        }
        return nil
    }
}

//TODO: needs switch statements
//class SwitchStatementsQuery: CodeSmellQuery {
//}


class TraditionBreakerQuery: CodeSmellQuery {
    var name: String = "TraditionBreaker"
    let lowNumberOfmethodsAndAttributes = Metrics.lowNumberOfMethodsAndAttributes
    let veryHighNumberOfMethodsAndAttributes = Metrics.veryHighNumberOfMethodsAndAttributes
    
    var description: String = "Queries classes that do not have any subclasses, where number of methods and attributes is low and where they inherit from a class whose number of methods and attributes is very high."
    
    func queryStringFor(classInstance: Class) -> String? {
        if let id = classInstance.id {
            return
            """
            MATCH (c:Class) where id(c) = \(id)
             MATCH (c:Class)-[r:EXTENDS]->(parent:Class)
             WHERE
                 NOT ()-[:EXTENDS]->(c) AND
                 c.number_of_methods + c.number_of_attributes < \(lowNumberOfmethodsAndAttributes) AND
                 parent.number_of_methods + parent.number_of_attributes >= \(veryHighNumberOfMethodsAndAttributes)
            SET cl.is_tradition_breaker = TRUE
            """
        }
        return nil
    }
}

//TODO: implement
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




