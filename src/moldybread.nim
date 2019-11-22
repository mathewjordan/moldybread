import httpClient, streams, strutils, xmltools

type
  FedoraConnection* = ref object
    base_url*: string
    results*: seq[string]
    query*: string
    max_results*: int

var client = newHttpClient()

proc grab_pids(response: string): seq[string] =
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
  var token: string = ""
  if results.len > 0:
    token = results.replace("<token>", "").replace("</token>", "")
  return token

proc populate_results(connection: FedoraConnection): seq[string] =
  var pids: seq[string] = @[]
  var new_pids: seq[string] = @[]
  var token: string = "temporary"
  var url: string = connection.base_url & "/fedora/objects?query=pid%7E" & connection.query & "*&pid=true&resultFormat=xml&maxResults=" & $connection.max_results
  var response: string = ""
  while token.len > 0:
    response = client.getContent(url)
    new_pids = grab_pids(response)
    for pid in new_pids:
      pids.add(pid)
    token = get_token(response)
    url = connection.base_url & "/fedora/objects?query=pid%7E" & connection.query & "*&pid=true&resultFormat=xml&maxResults=" & $connection.max_results & "&sessionToken=" & token
  return pids  

var fedora_connection: FedoraConnection = FedoraConnection(base_url:"http://localhost:8080", query: "test", max_results: 2)
fedora_connection.results = populate_results(fedora_connection)
echo fedora_connection.results
