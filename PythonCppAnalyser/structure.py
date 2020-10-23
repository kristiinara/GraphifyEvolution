# Compatibility with source kitten
sourceKittenIndex = { # basic structure of class + related classes, methods, variables
    "key.entities": [
        {
            "key.path": ""      # currently not used, but could rewrite analysis code to use it
            "key.kind": "",     # sourcekitten kind - class, struct, protocol, extension (not necessary), 
            "key.name": "",     # node.spelling
            "key.usr": "",      # node.usr
            #"key.line": "",     # is this needed?
            #"key.column": "", 
            "key.startLine": "", # currently not yet used, but makes more sense than finding from structure
            "key.endLine": "",  # see above + dataString between lines (prob. need some kind of update)
            "key.related": [
                {
                    "key.kind": "", # class, struct, protocol
                    "key.name": "",
                    "key.usr": ""
                }
            ],
            "key.entities": [
                {
                    "key.name": "",
                    "key.kind": "", # decl.function (class, static, instance), decl.variable (instance, class, static)
                    "key.usr": "",
                    "key.startLine": "",
                    "key.endLine": "",
                    "key.type": "", # e.g. return type, function type
                    "key.attributes": [
                            "attribute-name"
                        # what kind??
                    ],
                    "key.entities": [
                        {
                            # same as under last "key.entities"
                        }
                    ],
                    "key.related": [ # figure out how this is given in c++
                        {
                            "key.kind": "",
                            "key.name": "",
                            "key.usr": ""
                        }
                    ]
                }
            ]
        }
    ]
}

sourceKittenStructure = { # info with parameters and instructions
    "key.substructure": [   # classes?
        {   
            "key.kind": "",
            "key.name": "",
            "key.substructure": [ # methods and variables
                {
                    "key.kind": "",
                    "key.name": "",
                    "key.typename": "",
                    "key.accessability": "", # ??
                    "key.substructure": [ # if count == 0 or does not exist and method --> abstract method
                        {
                            "key.kind": "", # localVariable, MethodCall, For, ForEach, While, RepeatWhile, If, Guard, Switch, Case
                            "key.name": "",
                            "key.typename": "", # if parameter, then add
                            "key.offset": "" # how is this used??
                            "key.substructure": [
                                # same as above
                            ]
                        }
                    ]
                }
            ]
        }
    ]
}

allStructures = {
    "filePath": sourceKittenStructure
}

sourceKittenInfo = { # adds type if type is empty --> seems like we don't need it!
    "key.substructure": [
        {
            "key.name": "", # class name
            "key.substructure": [
                {
                    "key.name": "",
                    "key.kind": "", #variables: class, local, static, instance, global; methods: class, static, instance
                    "key.typename": ""
                }
            ]
        }
    ]
}


# needs to be changed: 
#   stuff in translateEntitiesToApp

