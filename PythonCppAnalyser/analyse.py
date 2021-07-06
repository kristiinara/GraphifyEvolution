#! /usr/bin/python

import clang.cindex
import os
import json
#import ccsyspath
import sys
from clang.cindex import CursorKind

from pprint import pprint

maxDepth = 1000

# currently not used
def get_cursor_id(cursor, cursor_list = []):
    if cursor is None:
        return None

    for i,c in enumerate(cursor_list):
        if cursor == c:
            return i
    cursor_list.append(cursor)
    return len(cursor_list) - 1

# currently not used
def get_info(node, depth=0):
    if depth >= maxDepth:
        children = None
        nodes = None
    else: 
        children = [get_info(c, depth+1) for c in node.get_children()]

    file = node.location.file
    if file == None:
        fileName = None
    else:
        fileName = file.name

    return { 'id' : get_cursor_id(node),
             'kind' : node.kind,
             'type' : node.type.spelling,
             'usr' : node.get_usr(),
             'spelling' : node.spelling,
             'location' : node.location,
             'location.file': fileName, 
             'extent.start' : node.extent.start,
             'extent.end' : node.extent.end,
             'is_definition' : node.is_definition(),
             'definition id' : get_cursor_id(node.get_definition()),
             'children' : children,
           #  'nodes': nodes 
           }

def analyse_file(index, path, args):
    translation_unit = index.parse(path, args = args) # need to check if this include really works!
    fileName = path.split("/")[-1]
    
    # todo: not setting header name?
    headerName = fileName.replace(".cpp", ".h")
    nameSpaces = []
    references = {}
    #allClasses = []

    children = translation_unit.cursor.get_children()

    for node in children:
        if node.kind == CursorKind.NAMESPACE:

            file = node.location.file
            if file == None:
                nodeFileName = None
            else:
                nodeFileName = file.name

            if fileName in nodeFileName or headerName in nodeFileName:
                nameSpaces.append(node)

    for node in nameSpaces:
        find_classes(node, fileName, headerName, os.path.abspath(path))

    for node in nameSpaces:
        fill_classes(node, fileName, allClasses, os.path.abspath(path))

    return allClasses

def fill_classes(node, fileName, classes, abspath):
    for child in node.get_children():
        file = child.location.file
        if file == None:
            nodeFileName = None
        else:
            nodeFileName = file.name

        if fileName in nodeFileName: # we are looking at the correct .cpp file
            name = child.spelling
            usr = child.get_usr()
            nodetype = child.type.spelling

            num_lines = sum(1 for line in open(abspath))

            existingEntity = None
            foundClassInstance = None

            for classInstance in list(classes.values()):
                for entity in classInstance["key.entities"]:
                    if entity["key.usr"] == usr:
                        existingEntity = entity
                        foundClassInstance = classInstance
                        #print "----- found existing entity: ", name
                        break

            if foundClassInstance is None:
                for classInstance in list(classes.values()):
                    if fileName in classInstance["fileName"]:
                        foundClassInstance = classInstance

            if foundClassInstance is None:
                foundClassInstance = {
                        'key.name': fileName,
                        'key.path': abspath,
                        'key.kind': "source.lang.swift.decl.class",
                        'type': "NA", 
                        'key.entities': [], 
                        'fileName': fileName, 
                        'headerName': fileName, 
                        'path': fileName,
                        'key.startLine': 0,
                        'key.endLine': 0
                        # 'key.related': [] # add super classes etc
                        }
                allClasses[usr] = foundClassInstance

            foundClassInstance["key.startLine"] = 1
            foundClassInstance["key.endLine"] = num_lines

            if child.is_definition():

                if child.kind == CursorKind.CONSTRUCTOR:
                    handleMethod(existingEntity, child, foundClassInstance)

                elif child.kind == CursorKind.CXX_METHOD:
                    handleMethod(existingEntity, child, foundClassInstance)

                elif child.kind == CursorKind.FUNCTION_DECL: # whats the difference??
                    handleMethod(existingEntity, child, foundClassInstance)

                elif child.kind == CursorKind.VAR_DECL:
                    handleVariable(existingEntity, child, foundClassInstance)

                elif child.kind == CursorKind.FIELD_DECL:
                    handleVariable(existingEntity, child, foundClassInstance)


def handleMethod(method, node, classInstance):
    startLine = node.extent.start.line
    endLine = node.extent.end.line

    functions.append(node)

    if method == None:
        name = node.spelling
        usr = node.get_usr()
        nodetype = node.type.spelling

        return_type = ""
        split_type = nodetype.split(" (")
        if len(split_type) > 1:
            return_type = split_type[0]


        method = {
            'key.name': name, 
            'key.usr': usr, 
            'key.type': nodetype,
            'key.kind': translateKindToSourceKittenKind(node.kind),
            'key.returnType': return_type
        }

        classInstance["key.entities"].append(method)

    method['key.endLine'] = endLine
    method['key.startLine'] = startLine

    if not "key.entities" in method:
        method["key.entities"] = []

    for child in node.get_children():
        handleSubitem(child, method)

def handleSubitem(node, parent):
    childName = node.spelling
    childUsr = node.get_usr()
    childNodetype = node.type.spelling
    childKind = str(node.kind)
    startLine = node.extent.start.line
    endLine = node.extent.end.line

    if node.kind == CursorKind.CALL_EXPR or node.kind == CursorKind.VARIABLE_REF or node.kind == CursorKind.MEMBER_REF:
        defNode = node.get_definition()
        if not defNode is None:
            #print "def", defNode
            childUsr = defNode.get_usr()

    subItem = {
        'key.name': childName, 
        'key.usr': childUsr, 
        'key.type': childNodetype, 
        'kind': str(childKind),
        'key.kind': translateKindToSourceKittenKind(childKind),
        'key.startLine': startLine,
        'key.endLine': endLine
        #'key.attributes': [], # TODO: figure this out!
        #'key.related':[]
    }

    if node.kind == CursorKind.CALL_EXPR:
        calls.append({"node": node, "item": subItem})

    if node.kind == CursorKind.MEMBER_REF:
        variable_references.append({"node": node, "item": subItem})

    if not "key.entities" in parent:
        parent["key.entities"] = []

    parent["key.entities"].append(subItem)

    for child in node.get_children():
        handleSubitem(child, subItem)

def translateKindToSourceKittenKind(kind): 
    kittenKind = ""
    if kind == CursorKind.CONSTRUCTOR:
        kittenKind = 'source.lang.swift.decl.function.method.instance' # + CursorKind.DESTRUCTOR ??
    elif kind == CursorKind.CXX_METHOD or kind == CursorKind.OBJC_CLASS_METHOD_DECL or kind == CursorKind.CONVERSION_FUNCTION:
        kittenKind = 'source.lang.swift.decl.function.method.class'
    elif kind == CursorKind.FUNCTION_DECL or kind == CursorKind.OBJC_INSTANCE_METHOD_DECL or kind == CursorKind.FUNCTION_TEMPLATE: #?? (abstract method?)
        kittenKind = 'source.lang.swift.decl.function.method.instance'
    elif kind == CursorKind.VAR_DECL:
        kittenKind = 'source.lang.swift.decl.var.local' # just variable declaration (can be on file level or inside a function)
    elif kind == CursorKind.FIELD_DECL:
        kittenKind = 'source.lang.swift.decl.var.instance' # member of class, not static! (so instance is correct :)) + CursorKind.OBJC_IVAR_DECL
    elif kind == CursorKind.PARM_DECL:
        kittenKind = 'source.lang.swift.decl.var.parameter'
    elif kind == 'CursorKind.CLASS_DECL':
        kittenKind = 'source.lang.swift.decl.class'
    elif kind == CursorKind.OBJC_INTERFACE_DECL or kind == CursorKind.OBJC_PROTOCOL_DECL or kind == CursorKind.CLASS_TEMPLATE: # todo: protocol vs interface?
        kittenKind = 'source.lang.swift.decl.protocol'
    elif kind == CursorKind.MEMBER_REF or kind == CursorKind.VARIABLE_REF or kind == CursorKind.CALL_EXPR or kind == CursorKind.OBJC_MESSAGE_EXPR:
        kittenKind = 'source.lang.swift.expr.call'
    elif kind == CursorKind.IF_STMT:
        kittenKind = 'source.lang.swift.stmt.if'
    elif kind == CursorKind.FOR_STMT:
        kittenKind = 'source.lang.swift.stmt.for'
    elif kind == CursorKind.WHILE_STMT:
        kittenKind = 'source.lang.swift.stmt.while'
    elif kind == CursorKind.SWITCH_STMT:
        kittenKind = 'source.lang.swift.stmt.switch'
    elif kind == CursorKind.SWITCH_STMT:
        kittenKind = 'source.lang.swift.stmt.switch'
    elif kind == CursorKind.CASE_STMT:
        kittenKind = 'source.lang.swift.stmt.case'
    elif kind == CursorKind.STRUCT_DECL:
        kittenKind = 'source.lang.swift.decl.struct'
    #else:
        #print "kind", kind, "not matched"

    return kittenKind


def handleVariable(variable, node, classInstance):
    startLine = node.extent.start.line
    endLine = node.extent.end.line

    variables.append(node)

    if variable == None:
        name = node.spelling
        usr = node.get_usr()
        nodetype = node.type.spelling
        kind = str(node.kind)

        variable = {
            'key.name': name, 
            'key.usr': usr, 
            'key.type': nodetype,
            'kind': kind,
            'key.kind': translateKindToSourceKittenKind(kind)
            #'key.attributes': [], # TODO: figure this out!
            #'key.related':[]
        }

        classInstance["key.entities"].append(variable)

    variable['key.endLine'] = endLine
    variable['key.startLine'] = startLine


def find_classes(node, fileName, headerName, abspath):
    #classes = {}
    for subnode in node.get_children():
        if subnode.kind == CursorKind.CLASS_DECL or subnode.kind == CursorKind.STRUCT_DECL or subnode.kind == CursorKind.ENUM_DECL:
            className = subnode.spelling
            classUsr = subnode.get_usr()
            classType = subnode.type.spelling
            classStartLine = subnode.extent.start.line # TODO: check! thise might not be correct as they come from the header file
            classEndLine = subnode.extent.end.line
            classKind = ""

            #print "class ", className, classUsr

            if subnode.is_abstract_record():
                #print "is abstract class: ", className
                classKind = "source.lang.swift.decl.protocol"
            else:
                #print "is not abstract class: ", className
                classKind = "source.lang.swift.decl.class"

            file = subnode.location.file
            if file == None:
                nodeFileName = None
            else:
                nodeFileName = file.name

            if fileName in nodeFileName or headerName in nodeFileName:
                #methods = []
                #variables = []
                entities = []

                for child in subnode.get_children():
                    name = child.spelling
                    usr = child.get_usr()
                    nodetype = child.type.spelling

                    #print "--", name, usr, nodetype

                    objectFound = {
                        'key.name': name, 
                        'key.usr': usr, 
                        'key.type': nodetype,
                        'kind': str(child.kind),
                        # 'key.related': [] # add overridden methods etc (kind, name, usr)
                        # 'key.attributes': [] # add attribute names, figure out what this means --> is it used somewhere?
                    }

                    kind = translateKindToSourceKittenKind(child.kind)

                    objectFound["key.kind"] = kind
                    entities.append(objectFound)

                    functions.append(child)
                    variables.append(child)

                if len(entities) == 0:
                    continue

                if classUsr in allClasses:
                    classInstance = allClasses[classUsr]
                    classInstance["key.entities"] = classInstance["key.entities"] + entities
                else:

                    allClasses[classUsr] = {
                        'key.name': className, 
                        'key.usr': classUsr, 
                        'key.path': abspath,
                        'key.kind': classKind,
                        'type': classType, 
                        'key.entities': entities, 
                        'fileName': fileName, 
                        'headerName': headerName, 
                        'path': nodeFileName,
                        'key.startLine': classStartLine,
                        'key.endLine': classEndLine
                        # 'key.related': [] # add super classes etc
                        }

            #else:
                #print "filename", nodeFileName, "not current file", fileName, "or", headerName
        #else:
            #print "kind not class: ", subnode.kind
    return allClasses

def correctReferences():
    for callData in calls:
        node = callData["node"]
        item = callData["item"]
        #print "item: ", node.spelling

        found = False

        nodeDef = node.get_definition()

        if nodeDef is not None:
            for function in functions:
                if nodeDef == function:
                    item["key.usr"] = function.get_usr()
                    item["matchedFunction"] = function.spelling
                    found = True
                    #print "found:", function.spelling
        #else: 
            #print "nodeDef is none"

        if not found:
            for function in functions:
                return_type = ""
                nodetype = function.type.spelling
                split_type = nodetype.split(" (")
                if len(split_type) > 1:
                    return_type = split_type[0]

                if function.spelling == node.spelling and return_type == node.type.spelling:
                    item["key.usr"] = function.get_usr()
                    item["matchedFunction"] = function.spelling

    for v_reference in variable_references:
        node = v_reference["node"]
        item = v_reference["item"]
        #print "item: ", node.spelling

        found = False
        nodeDef = node.get_definition()

        if nodeDef is not None:
            for variable in variables:
                if nodeDef == variable:
                    item["key.usr"] = variable.get_usr()
                    item["matchedVariable"] = variable.spelling
                    found = True
                    #print "found:", variable.spelling

        if not found: 
            for variable in variables:
                v_type = variable.type.spelling
                if variable.spelling == node.spelling and v_type == node.type.spelling:
                    item["key.usr"] = variable.get_usr()
                    item["matchedVariable"] = variable.spelling


# needed later: CursorKind.TYPE_REF

###
# class
#   usr
##  headerPath
##  path
##  methods + constructors
###     name
###     arguments
###     return type
###     usr
##  variables
###     name
###     type
###     usr


# TODO: rewrite:
## - look into if we can analyse the whole project at once
## - analyse class: for both .h and .cpp file
## - if method has no implementation --> save as method declaration?
## - if has implementation --> save as method implementation?
## --- method declaration == abstract method? 


#print("hello")

clang.cindex.Config.set_library_path("/usr/local/Cellar/llvm/9.0.0_1/lib/")

index = clang.cindex.Index.create()

if len(sys.argv) == 2:
    directoryPath = sys.argv[1]
    includePath = directoryPath + 'include/'
    sourcePath = directoryPath + 'src/'
    
    args = [('-I/' + includePath), '-x', 'c++', '-I/usr/local/opt/llvm/bin/../include/c++/v1', '-I/usr/local/Cellar/llvm/9.0.0_1/lib/clang/9.0.0/include', '-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include', '-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks', '-std=c++1z']
    
    allClasses = {}
    functions = []
    variables = []
    calls = []
    variable_references = []
    
    for fileName in os.listdir(sourcePath):
        if fileName.endswith(".cpp"):
            classes = analyse_file(index, sourcePath + fileName, args = args)
    
    #for fileName in os.listdir(includePath):
    #    if fileName.endswith(".h"):
    #        classes = analyse_file(index, includePath + fileName, args = args)

    correctReferences()
    print(json.dumps(list(allClasses.values()), indent=4))
    
else:
    print 'Incorrect input, argument should be directory path'
