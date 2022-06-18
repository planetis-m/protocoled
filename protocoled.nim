## Interface macro for Nim
## =======================
##
## The protocol macro allows writing an interface with less typing. Classes
## implementing that interface are defined using the ``impl`` command inside
## the macro statement. Works in a similar way to the class macro.
## It requires a typeless parameter, acting as the 'self' variable, to be
## declared in all procedures, but the ctor. Prefix with the export marker to
## make a class definition public. The constructor and clone function should
## explicitly use the result variable.
##
## Example:
## ========
##
## .. code-block:: nim
##   protocol *IUpdatable:
##     proc update*(this)
##
##     impl Movable:
##       proc update(this) =
##         echo("Moving forward.")
##
##       proc newMovable(): Movable =
##         new(result)
##
##     impl *NotMovable:
##       proc update(this) =
##         echo("I'm staying put.")
##
##       proc newNotMovable*(): NotMovable =
##         new(result)
##
import macros

type
   ClassBuilder = ref object
      baseType: NimNode
      methNames: seq[string]

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

   template shadowThisVar(body, varName, typ) =
      body.insert(0, newLetStmt(varName, newCall(typ, varName)))
   template assignResField(body, field, procName) =
      body.add(nnkAsgn.newTree(nnkDotExpr.newTree(ident("result"), field), procName))

   expectKind(node[2], nnkStmtList)
   for n in node[2].children:
      case n.kind
      of nnkProcDef:
         # Check if it is the ctor proc or a clone function
         if eqIdent(n.params[0], $derivType):
            # Assign the fields of the result
            for name in b.methNames:
               n.body.assignResField(ident(name & "impl"), ident(name & $derivType))
         else:
            if n.params.len < 2 or n.params[1][1].kind != nnkEmpty:
               error(n.params.lineInfo & ": Proc's 'this' parameter not found")
            for name in b.methNames:
               if eqIdent(n.name, name):
                  n.params[1][1] = b.baseType
                  let thisVar = n.params[1][0]
                  # cast 'this' variable to class type
                  n.body.shadowThisVar(thisVar, derivType)
                  n[0] = ident(name & $derivType) # overrides the export marker
                  break
         # If proc is not a method, 'this' var has the type of the derived class
         if n.params.len >= 2 and n.params[1][1].kind == nnkEmpty:
            n.params[1][1] = derivType
         result.add n
      of nnkVarSection, nnkLetSection:
         n.copyChildrenTo(recList)
      else:
         error(n.lineInfo & ": Invalid node: " & n.repr)

macro protocol*(head, body): untyped =
   result = newStmtList()
   let b = ClassBuilder()
   # Create a type section for the base class
   let interDecl = createType(head, ident("RootObj"))
   b.baseType = interDecl[0][0].basename
   let recList = interDecl[0][2][0][2]
   result.add interDecl

   template addObjField(record, name, params) =
      record.add(nnkIdentDefs.newTree(name, nnkProcTy.newTree(params,
                 nnkPragma.newTree(ident("nimcall"))), newEmptyNode()))
   template checkNotNil(name, field) =
      assert(name.field != nil)

   template forwardCall(body, name, field, params): NimNode =
      body.add(nnkCall.newTree(nnkDotExpr.newTree(name, field)).add(params))

   for n in body.children:
      case n.kind
      of nnkProcDef:
         if n.params.len < 2 or n.params[1][1].kind != nnkEmpty:
            error(n.params.lineInfo & ": Method's 'self' parameter not found")
         n.params[1][1] = b.baseType
         let thisVar = n.params[1][0]
         expectKind(n.body, nnkEmpty) # Only a proc signature
         # Add proc field to interface type signature
         let objField = ident($n.name & "impl")
         recList.addObjField(objField, n.params)
         # List of the methods defined in the interface
         b.methNames.add($n.name)
         # Obtain the names of the parameters
         var params: seq[NimNode]
         for i in 1 ..< n.params.len:
            params.add n.params[i][0]
         n.body = newStmtList()
         n.body.add getAst(checkNotNil(thisVar, objField))
         # Forward call to implementation proc
         n.body.forwardCall(thisVar, objField, params)
         result.add n
      of nnkCommand:
         expectKind(n[0], nnkIdent)
         if $n[0] != "impl": error("Invalid command " & $n[0])
         assert b.methNames.len > 0, "No methods declared"
         let implClass = transformClass(n, b)
         result.add implClass
      else:
         error(n.lineInfo & ": Invalid node: " & n.repr)

when isMainModule:
   protocol *IUpdatable:
      proc update*(this)

      impl Movable:
         proc update(this) =
            echo("Moving forward.")
         proc newMovable(): Movable =
            new(result)

      impl *NotMovable:
         proc update(this) =
            echo("I'm staying put.")
         proc newNotMovable*(): NotMovable =
            new(result)
