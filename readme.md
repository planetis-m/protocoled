
# Protocoled — an interface macro for Nim

## About
This nimble package contains two macros. One for easily implementing
[interfaces](https://en.wikipedia.org/wiki/Composition_over_inheritance)
in Nim, and a much simpler one to create a class hierarchy.

### The `protocol` macro
Example:

```nim
import protocoled

protocol PExpr:
   proc eval(e): int

   impl PLiteral:
      var x: int
      proc eval(e): int = e.x
      proc newLit(x: int): PLiteral =
         result = PLiteral(x: x)

   impl PPlusExpr:
      var a, b: PExpr
      proc eval(e): int = eval(e.a) + eval(e.b)
      proc newPlus(a, b: PExpr): PPlusExpr =
         result = PPlusExpr(a: a, b: b)
```
Notice the typeless parameter `e`, the macro takes care of assigning it the
proper type. Then it is translated roughly into this code:

```nim
type
   PExpr = ref object of RootObj ## abstract base class for an expression
      evalImpl: proc(e: PExpr): int {.nimcall.}
   PLiteral = ref object of PExpr
      x: int
   PPlusExpr = ref object of PExpr
      a, b: PExpr

proc eval(e: PExpr): int =
   assert e.evalImpl != nil
   e.evalImpl(e)

proc evalLit(e: PExpr): int = PLiteral(e).x
proc evalPlus(e: PExpr): int = eval(PPlusExpr(e).a) + eval(PPlusExpr(e).b)

proc newLit(x: int): PLiteral = PLiteral(evalImpl: evalLit, x: x)
proc newPlus(a, b: PExpr): PPlusExpr = PPlusExpr(evalImpl: evalPlus, a: a, b: b)
```

### The `class` macro
```nim
import schooled

class Human:
   var name: string

   method greet(this) =
      echo("Greetings!")

   impl Student:
      var id: int

      method greet(this) =
         echo("Sup!")

      proc newStudent(): Student =
         new(result)

   impl Professor:
      method greet(this) =
         echo("Greetings!")

      proc newProfessor(): Professor =
         new(result)
```

### Known quirks
You need to separate the `self` parameter from the rest with a semicolon.

### License

This library is distributed under the MIT license. For more information see `copying.txt`.
