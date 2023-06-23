# Package

version       = "0.1.0"
author        = "Antonis"
description   = "An interface macro for Nim"
license       = "MIT"
#srcDir        = "src"



# Dependencies

requires "nim >= 1.0.9"

after install:
  when defined(linux):
    echo "hello"
