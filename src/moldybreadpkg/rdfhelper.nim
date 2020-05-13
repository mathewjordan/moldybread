import strutils, strformat

type
    TurtleTriple* = ref object
        subject*: string
        predicate*: string
        obj*: string

proc newTriple*(rdf: string): TurtleTriple =
    ## Constructs a Turtle Triple from a string of TTL
    let parsed = rdf.split(" ")
    TurtleTriple(subject: parsed[0], predicate: parsed[1], obj: parsed[2])

when isMainModule:
    let x = newTriple("<info:fedora/test:22> <info:fedora/fedora-system:def/relations-external#isMemberOf> <info:fedora/test:21> .")
    echo fmt"subject: {x.subject}, predicate: {x.predicate}, object: {x.obj}"