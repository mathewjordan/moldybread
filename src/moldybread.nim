import httpClient, streams, strutils, xmltools, yaml.serialization

type
  FedoraConnection* = ref object
    base_url*: string
    results*: seq[string]
    query*: string
    max_results*: int

  ConfigSettings* = object
    username: string
    password: string
    base_url: string
    max_results: int
    output_directory: string

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
var fedora_connection: FedoraConnection = FedoraConnection(base_url:yaml_settings.base_url, query: "test", max_results: yaml_settings.max_results)
fedora_connection.results = populate_results(fedora_connection)
echo fedora_connection.results
