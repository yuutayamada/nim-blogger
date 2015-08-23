# Package

version       = "0.1.0"
author        = "Yuta Yamada"
description   = "Command line Blogger posting tool"
license       = "MIT"


bin = @["nimblogger"]

# Dependencies

requires "nim >= 0.12.1"

task make, "make":
  exec "nim c -d:ssl -d:release -r nimblogger.nim"
