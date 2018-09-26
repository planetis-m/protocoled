## Class macro for Nim
## ===================
## 
## The class macro allows implementing a class hierarchy with less typing
## subclasses are defined using the ``impl`` command inside the macro statement.
## It requires a typeless parameter, acting as the 'self' variable, to be
## declared in all procedures, but the ctor. Prefix with the export marker to
## make a class definition public.
## 
## Example:
## ========
## 
## .. code-block:: nim
##   class *Human:
##     var name: string
## 
##     method greet*(this) =
##       echo("Greetings!")
## 
##     impl Student:
##       var id: int
## 
##       method greet(this) =
##         echo("Sup!")
## 
##       proc newStudent(): Student =
##         new(result)
## 
##     impl *Professor:
##       method greet*(this) =
##         echo("Greetings!")
## 
##       proc newProfessor*(): Professor =
##         new(result)
## 
import macros

type
   ClassBuilder = ref object
      baseType: NimNode

proc createType(node, baseType: NimNode): NimNode =
   expectKind(baseType, nnkIdent)
   # flag if object should be exported
   var isExported = false
   if node.kind == nnkPrefix and $node[0] == "*":
      isExported = true
   elif node.kind != nnkIdent:
      error(node.lineInfo & ": Invalid node: " & node.repr)
   let classType = node.basename

   template declare(a, b) =
      type a = ref object of b

   template declarePub(a, b) =
      type a* = ref object of b

   result =
      if isExported:
         getAst(declarePub(classType, baseType))
      else:
         getAst(declare(classType, baseType))

   result[0][2][0][2] = newNimNode(nnkRecList)

proc transformClass(node: NimNode, b: ClassBuilder): NimNode =
   result = newStmtList()
   expectKind(node, nnkCommand)
   # Create a type section for the derived class
   let derivDecl = createType(node[1], b.baseType)
   let derivType = derivDecl[0][0].basename
   let recList = derivDecl[0][2][0][2]
   result.add derivDecl

   expectKind(node[2], nnkStmtList)
   for n in node[2].children:
      case n.kind
      of nnkProcDef, nnkMethodDef:
         # Check if it is the ctor proc or a clone function
         if not eqIdent(n.params[0], $derivType):
            if n.params.len < 2 or n.params[1][1].kind != nnkEmpty:
               error(n.params.lineInfo & ": Procs's 'this' parameter not found")
         if n.params.len >= 2 and n.params[1][1].kind == nnkEmpty:
            n.params[1][1] = derivType
         result.add n
      of nnkVarSection:
         n.copyChildrenTo(recList)
      else:
         error(n.lineInfo & ": Invalid node: " & n.repr)

macro class*(head, body): untyped =
   result = newStmtList()
   let b = ClassBuilder()
   # Create a type section for the base class
   let interDecl = createType(head, ident("RootObj"))
   b.baseType = interDecl[0][0].basename
   let recList = interDecl[0][2][0][2]
   result.add interDecl

   for n in body.children:
      case n.kind:
      of nnkProcDef, nnkMethodDef:
         if n.params.len < 2 or n.params[1][1].kind != nnkEmpty:
            error(n.params.lineInfo & ": Proc's 'this' parameter not found")
         n.params[1][1] = b.baseType
         if n.kind == nnkMethodDef: n.addPragma(ident("base"))
         result.add n
      of nnkCommand:
         if $n[0] != "impl": error("Invalid command " & $n[0])

         let implClass = transformClass(n, b)
         result.add implClass
      of nnkVarSection:
         n.copyChildrenTo(recList)
      else:
         error(n.lineInfo & ": Invalid node: " & n.repr)

when isMainModule:
   class *Human:
      var name: string

      method greet(this) =
         echo("Greetings!")

      impl Student:
         var id: int

         method greet(this) =
            echo("Sup!")

         proc newStudent(): Student =
            new(result)

      impl *Professor:
         method greet(this) =
            echo("Greetings!")

         proc newProfessor*(): Professor =
            new(result)
