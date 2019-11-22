import httpClient, streams, strutils, xmltools, yaml.serialization, base64

type
  FedoraConnection* = ref object
    base_url*: string
    results*: seq[string]
    query*: string
    max_results*: int
    output_directory: string
    authentication: (string, string)

  ConfigSettings* = object
    username: string
    password: string
    base_url: string
    max_results: int
    output_directory: string
  
  Message* = ref object
    errors*: seq[string]
    successes*: seq[string]
    attempts*: int

var client = newHttpClient()

proc grab_pids*(response: string): seq[string] =
  var pids: seq[string] = @[]
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "pid")
  for word in split(results, '<'):
    let new_word = word.replace("/", "").replace("pid>", "")
    if len(new_word) > 0:
      pids.add(new_word)
  return pids

proc get_token*(response: string): string =
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "token")
  var token: string = ""
  if results.len > 0:
    token = results.replace("<token>", "").replace("</token>", "")
  return token
  
proc harvest_metadata(datastream_id: string, connection: FedoraConnection): Message =
  var url: string
  var successes, errors: seq[string]
  var attempts: int
  for pid in connection.results:
    url = connection.base_url  & "/fedora/objects/" & pid & "/datastreams/" & datastream_id & "/content"
    client.headers["Authorization"] = "Basic " & base64.encode(connection.authentication[0] & ":" & connection.authentication[1])
    var response = client.request(url, httpMethod = HttpGet)
    if response.status == "200 OK":
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
  attempts = attempts
  let message: Message = Message(errors: errors, successes: successes, attempts: attempts)
  return message

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

proc read_yaml_config(file_path: string): ConfigSettings =
  var config_settings: ConfigSettings
  var file_stream = newFileStream(file_path)
  load(file_stream, config_settings)
  file_stream.close()
  return config_settings

var yaml_settings = read_yaml_config("/home/mark/nim_projects/moldybread/config/config.yml")
var fedora_connection: FedoraConnection = FedoraConnection(base_url:yaml_settings.base_url,
 query: "test", 
 max_results: yaml_settings.max_results,
 output_directory: yaml_settings.output_directory,
 authentication: (yaml_settings.username, yaml_settings.password)
 )
fedora_connection.results = populate_results(fedora_connection)
let test = harvest_metadata("MODS", fedora_connection)
