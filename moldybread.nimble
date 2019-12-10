# Package

version       = "0.1.0"
author        = "Mark Baggett"
description   = "A Fedora 3.8 client in nim"
license       = "GPL-3.0"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["moldybread"]


# Dependencies

requires "nim >= 1.0.2"
requires "xmltools >= 0.1.5"
requires "yaml >= 0.12.0"
requires "argparse >= 0.10.0"
requires "progress >=  1.1.1"
