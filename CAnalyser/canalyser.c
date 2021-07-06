#include <clang-c/Index.h>
#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>
#include <libgen.h>

// --- Sources used ---
// tips on how to compile (using clang) correctly: https://embeddedartistry.com/blog/2017/02/24/installing-llvm-clang-on-osx/
// gettng started with clang: https://bastian.rieck.me/blog/posts/2015/baby_steps_libclang_ast/
// further documentation on creating translation unit and traversing the AST from here: https://clang.llvm.org/doxygen/group__CINDEX.html#ga51eb9b38c18743bf2d824c6230e61f93
// starting point for working with files: https://www.codespeedy.com/get-all-files-in-a-directory-with-a-specific-extension-in-cpp/
// ends_with function: https://stackoverflow.com/questions/744766/how-to-compare-ends-of-strings-in-c
// checking for directory: https://stackoverflow.com/questions/4553012/checking-if-a-file-is-a-directory-or-just-a-file
// starting point for getting list of files: https://stackoverflow.com/questions/26357792/return-a-list-of-files-in-a-folder-in-c
// file name from path: https://man7.org/linux/man-pages/man3/basename.3.html

typedef struct parser_status {
    int count;
    char *fileName;
} parser_status;

int ends_with(const char *str, const char *suffix) {
  size_t str_len = strlen(str);
  size_t suffix_len = strlen(suffix);

  return (str_len >= suffix_len) &&
         (!memcmp(str + str_len - suffix_len, suffix, suffix_len));
}

int is_directory(const char *path) {
    struct stat path_stat;
    stat(path, &path_stat);
    return S_ISDIR(path_stat.st_mode);
}

char **scanDirectory(char dirname[], size_t *elems) {
    DIR *d = NULL;
    struct dirent *dir = NULL;
    char **list = NULL;

    d = opendir(dirname);
    if (d) {
        while ((dir = readdir(d)) != NULL) {
            char extendedPath[strlen(dirname) + strlen(dir->d_name) + 3];
            if(ends_with(dirname, "/")) {
                snprintf(extendedPath, sizeof(extendedPath), "%s%s", dirname, dir->d_name);
            } else {
                snprintf(extendedPath, sizeof(extendedPath), "%s/%s", dirname, dir->d_name);
            }
            
            if(is_directory(extendedPath) && !(ends_with(dir->d_name, ".") || ends_with(dir->d_name, ".."))) {
                if(!ends_with(dir->d_name, "test")) {
                    size_t count = 0;
                    char **subList = scanDirectory(extendedPath, &count);
                
                    list = realloc(list, sizeof(*list) * (*elems + count));
                
                    int i;
                    for(i=0; i < count; i++) {
                        list[(*elems)++] = strdup(subList[i]);
                        free(subList[i]);
                    }
                    free(subList);
                }
            } else if (ends_with(dir->d_name, ".c") || ends_with(dir->d_name, ".h") || ends_with(dir->d_name, ".cpp" || ends_with(dir->d_name, ".m"))) {
                list = realloc(list, sizeof(*list) * (*elems + 1));
                list[(*elems)++] = strdup(extendedPath);
            }
        }
        closedir(d);
    }
    return list;
}

void printOffset(int offsetCount) {
    int i;
    for(i = 0; i < offsetCount; i++) {
        printf("   ");
    }
}

void printWithCXString(char *key, CXString xstring, int offSet) {
    printOffset(offSet);
    char *string = clang_getCString(xstring);
    printf("\"%s\": \"%s\",\n",  key, string);
    clang_disposeString(xstring);
}

int firstVisitor = 1; // records if given cursor is the first child of parent (decides if printing should start with a comma)

enum CXChildVisitResult visitor(CXCursor cursor, CXCursor parent, CXClientData data) {
    CXSourceLocation location = clang_getCursorLocation(cursor);
    if( clang_Location_isFromMainFile(location) == 0 )
        return CXChildVisit_Continue;

    enum CXCursorKind cursorKind = clang_getCursorKind(cursor);

    struct parser_status *parserStatus = (parser_status*) data;
    
    unsigned int curLevel  = parserStatus->count;
    unsigned int nextLevel = curLevel + 1;
    
    if(cursorKind == CXCursor_ClassDecl) {
        //
    }
    
    printOffset(curLevel);
    if(firstVisitor) {
        printf("{\n");
    } else {
        printf(",{\n");
    }
    
    if(cursorKind != CXCursor_StringLiteral) {
        printWithCXString("key.name", clang_getCursorDisplayName(cursor), curLevel + 1);
    }
    printWithCXString("key.kind", clang_getCursorKindSpelling(cursorKind), curLevel + 1);
    
    
    if(cursorKind == CXCursor_MemberRef || cursorKind == CXCursor_VariableRef || cursorKind == CXCursor_DeclRefExpr || cursorKind == CXCursor_CallExpr || cursorKind == CXCursor_MemberRefExpr) {
        //printf("cursor referenced\n");
        printWithCXString("key.usr", clang_getCursorUSR(clang_getCursorReferenced(cursor)), curLevel + 1);
    } else {
        //printf("cursor definition\n");
        printWithCXString("key.usr", clang_getCursorUSR(clang_getCanonicalCursor(cursor)), curLevel + 1);
    }
    
    printOffset(curLevel + 1);
    printf("\"key.isCursorDefinition\": %i,\n", clang_isCursorDefinition(cursor));
    
    //printWithCXString("canonical", clang_getCursorUSR(clang_getCanonicalCursor(cursor)), 1);
    //printWithCXString("definition", clang_getCursorUSR(clang_getCursorDefinition(cursor)), 1);
    //printWithCXString("display name", clang_getCursorDisplayName(cursor), 1);
    //printWithCXString("cursor referenced", clang_getCursorUSR(clang_getCursorReferenced(cursor)), 1);
    
   
    printOffset(curLevel + 1);
    printf("\"key.path\": \"%s\",\n", parserStatus->fileName);
    
    CXSourceRange extent = clang_getCursorExtent(cursor);
    CXSourceLocation startLocation = clang_getRangeStart(extent);
    CXSourceLocation endLocation = clang_getRangeEnd(extent);

    unsigned int startLine = 0;
    unsigned int endLine = 0;

    clang_getSpellingLocation(startLocation, NULL, &startLine, NULL, NULL);
    clang_getSpellingLocation(endLocation, NULL, &endLine, NULL, NULL);
    
    printOffset(curLevel + 1);
    printf("\"key.startLine\": %i,\n", startLine);
    printOffset(curLevel + 1);
    printf("\"key.endLine\": %i,\n", endLine);
    
    // clang_getSpellingLocation()
    // clang_getRangeStart()
    // clang_getRangeEnd()
    // clang_getCursorExtent()
    
    /*
     still needs to be added:
        - key.type
        - key.returnType (if method)
        -
     */
    
    printOffset(curLevel + 1);
    printf("\"key.entities\": [ \n");

    struct parser_status newParserStatus = { nextLevel, parserStatus->fileName };
    
    firstVisitor = 1;
    clang_visitChildren(cursor, visitor, (CXClientData) &newParserStatus);
    firstVisitor = 0;
    
    printOffset(curLevel + 1);
    printf("]\n");

    printOffset(curLevel);
    printf("}\n");
    
    //TODO: look here: https://stackoverflow.com/questions/45430971/how-to-get-function-definition-signature-as-a-string-in-clang
    return CXChildVisit_Continue;
}

int main(int argc, char** argv) {
    if( argc < 2 ) {
        return -1;
    }
    
    char directoryPath[strlen(argv[1])];
    strcpy(directoryPath, argv[1]);

    /* // from my former working python project
    directoryPath = sys.argv[1]
    includePath = directoryPath + "include/"
    sourcePath = directoryPath + "src/"
    
    args = [("-I/" + includePath), "-x", "c++", "-I/usr/local/opt/llvm/bin/../include/c++/v1", "-I/usr/local/Cellar/llvm/9.0.0_1/lib/clang/9.0.0/include", "-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include", "-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks", "-std=c++1z"]
     */
    
    char *args[argc];
    int i;
    for(i = 2; i < argc ; i++) {
        args[i - 2] = argv[i];
    }

    CXIndex index = clang_createIndex( 0, 0 );
    if(!index) {
        printf("No index\n");
        return -1;
    }
    
    size_t count = 0;
    char **list = scanDirectory(directoryPath, &count);
    
    printf("[\n");

    for (i = 0; i < count; i++) {
        CXTranslationUnit tu = clang_createTranslationUnitFromSourceFile(index, list[i], argc - 3, args, 0, 0);
        
         if( !tu ) {
             printf("No translation unit\n");
             return -1;
         }
        
        CXCursor rootCursor  = clang_getTranslationUnitCursor( tu );
        
        struct parser_status parserStatus = { 0, list[i] };
        clang_visitChildren(clang_getTranslationUnitCursor(tu), visitor, (CXClientData)&parserStatus);

        clang_disposeTranslationUnit(tu);
        
        free(list[i]);
    }
    free(list);
    
    printf("]\n");
    

    

    clang_disposeIndex( index );

    return 0;
}
