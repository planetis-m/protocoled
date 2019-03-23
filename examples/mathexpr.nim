import "../protocoled"

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

echo eval(newPlus(newPlus(newLit(1), newLit(2)), newLit(4)))
