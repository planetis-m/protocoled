import "../protocoled"

# --------------------
# IUpdatable interface
# --------------------

protocol IUpdatable:
   proc update(this)

   impl Movable:
      proc update(this) =
         echo("Moving forward.")

      proc newMovable(): Movable = 
         result = Movable()

   impl NotMovable:
      proc update(this) =
         echo("I'm staying put.")

      proc newNotMovable(): NotMovable = 
         result = NotMovable()

# ---------------------
# ICollidable interface
# ---------------------

protocol ICollidable:
   proc collide(this)

   impl Solid:
      proc collide(this) =
         echo("Bang!")

      proc newSolid(): Solid = 
         result = Solid()

   impl NotSolid:
      proc collide(this) =
         echo("Splash!")

      proc newNotSolid(): NotSolid = 
         result = NotSolid()

# ------------------
# IVisible interface
# ------------------

protocol IVisible:
   proc draw(this)

   impl Invisible:
      proc draw(this) =
         echo("I won't appear.")

      proc newInvisible(): Invisible = 
         result = Invisible()

   impl Visible:
      proc draw(this) =
         echo("I'm showing myself.")

      proc newVisible(): Visible = 
         result = Visible()
