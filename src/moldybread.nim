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
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "pid")
  for word in split(results, '<'):
    let new_word = word.replace("/", "").replace("pid>", "")
    if len(new_word) > 0:
      result.add(new_word)

proc get_token*(response: string): string =
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "token")
  if results.len > 0:
    result = results.replace("<token>", "").replace("</token>", "")

proc write_output(filename: string, contents: string, destination_directory: string): string =
  let path = destination_directory & "/" & filename
  writeFile(path, contents)
  result = "Created " & filename & " at " & destination_directory

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
      discard write_output(pid, response.body, connection.output_directory)
    else:
      errors.add(pid)
    attempts += 1
  attempts = attempts
  result = Message(errors: errors, successes: successes, attempts: attempts)

proc populate_results(connection: FedoraConnection): seq[string] =
  var new_pids: seq[string] = @[]
  var token: string = "temporary"
  var url: string = connection.base_url & "/fedora/objects?query=pid%7E" & connection.query & "*&pid=true&resultFormat=xml&maxResults=" & $connection.max_results
  var response: string = ""
  while token.len > 0:
    response = client.getContent(url)
    new_pids = grab_pids(response)
    for pid in new_pids:
      result.add(pid)
    token = get_token(response)
    url = connection.base_url & "/fedora/objects?query=pid%7E" & connection.query & "*&pid=true&resultFormat=xml&maxResults=" & $connection.max_results & "&sessionToken=" & token

proc read_yaml_config(file_path: string): ConfigSettings =
  var file_stream = newFileStream(file_path)
  load(file_stream, result)
  file_stream.close()

when isMainModule:
  var yaml_settings = read_yaml_config("/home/mark/nim_projects/moldybread/config/config.yml")
  var fedora_connection: FedoraConnection = FedoraConnection(base_url:yaml_settings.base_url,
  query: "test", 
  max_results: yaml_settings.max_results,
  output_directory: yaml_settings.output_directory,
  authentication: (yaml_settings.username, yaml_settings.password)
  )
  fedora_connection.results = populate_results(fedora_connection)
  let test = harvest_metadata("MODS", fedora_connection)
  echo test.successes
