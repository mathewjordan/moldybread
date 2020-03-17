# Package

version       = "0.1.4"
author        = "Mark Baggett"
description   = "A Fedora 3.8 client in nim"
license       = "GPL-3.0"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["moldybread"]


# Dependencies

requires "nim >= 1.0.2"
requires "xmltools >= 0.1.5"
requires "yaml >= 0.13.0"
requires "argparse >= 0.10.0"
requires "progress >=  1.1.1"

# Documentation

task docs, "Docs":
  exec "nim doc -o=docs --project --index:on --git.url:https://github.com/markpbaggett/moldybread --git.commit:$(git rev-parse HEAD) src/moldybread.nim"
  exec "nim buildIndex -o:docs/theindex.html docs"

task test, "Test":
  exec "nim c -r tests/test1.nim"
