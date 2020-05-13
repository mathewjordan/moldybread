import strutils

type
    TurtleTriple* = ref object
        subject*: string
        predicate*: string
        obj*: string

proc newTriple*(rdf: string): TurtleTriple =
    ## Constructs a Turtle Triple from a string of TTL
    let parsed = rdf.split(" ")
    TurtleTriple(subject: parsed[0], predicate: parsed[1], obj: parsed[2])
