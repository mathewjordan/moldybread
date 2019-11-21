import httpClient, streams, strutils, xmltools

type
  FedoraConnection* = ref object
    base_url*: string
    response*: string
    results*: seq[string]
    token*: string

proc add_pids_to_results(response: string): seq[string] =
  var pids: seq[string] = @[]
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "pid")
  for word in split(results, '<'):
    let new_word = word.replace("/", "").replace("pid>", "")
    if len(new_word) > 0:
      pids.add(new_word)
  return pids

proc get_token(response: string): string =
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "token")
  return results

var client = newHttpClient()
var fedora_connection: FedoraConnection = FedoraConnection(base_url:"http://localhost:8080/fedora/objects?query=pid%7Etest*&pid=true&resultFormat=xml", response: client.getContent("http://localhost:8080/fedora/objects?query=pid%7Etest*&pid=true&resultFormat=xml"))

fedora_connection.results = add_pids_to_results(fedora_connection.response)
fedora_connection.token = get_token(fedora_connection.response)
