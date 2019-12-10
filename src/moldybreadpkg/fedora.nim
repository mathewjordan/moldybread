import httpclient, strformat, xmltools, strutils, base64, progress, os, typetraits

type
  FedoraRequest* = ref object
    ## Type to Handle Fedora requests
    base_url*: string
    results*: seq[string]
    client: HttpClient
    max_results*: int
    output_directory: string

  Message* = ref object
    ## Type to handle messaging
    errors*: seq[string]
    successes*: seq[string]
    attempts*: int

  FedoraRecord = object
    ## Type to handle Fedora Records
    client: HttpClient
    uri: string
    pid: string

proc get_path_with_pid(path, extension: string): seq[(string, string)] =
  var parts_of_path: seq[string]
  var pid: string
  for kind, path in walkDir(path):
    if kind == pcFile and path.contains(":"):
      parts_of_path = path.split("/")
      for value in parts_of_path:
        if value.contains(":"):
          pid = value.replace(extension, "")
      result.add((path, pid))

proc initFedoraRequest*(url: string="http://localhost:8080", auth=("fedoraAdmin", "fedoraAdmin")): FedoraRequest =
  ## Initializes new Fedora Request.
  ##
  ## Examples:
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest()
  ##
  let client = newHttpClient()
  client.headers["Authorization"] = "Basic " & base64.encode(auth[0] & ":" & auth[1])
  FedoraRequest(base_url: url, client: client, max_results: 1, output_directory: "/home/mark/nim_projects/moldybread/sample_output")

method grab_pids(this: FedoraRequest, response: string): seq[string] {. base .} =
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "pid")
  for word in split(results, '<'):
    let new_word = word.replace("/", "").replace("pid>", "")
    if len(new_word) > 0:
      result.add(new_word)

method get_token(this: FedoraRequest, response: string): string {. base .} =
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "token")
  if results.len > 0:
    result = results.replace("<token>", "").replace("</token>", "")

method get_cursor(this: FedoraRequest, response: string): string {. base .} =
  let xml_response = Node.fromStringE(response)
  let results = $(xml_response // "cursor")
  if results.len > 0:
    result = results.replace("<cursor>", "").replace("</cursor>", "")
  else:
    result = "No cursor"

method get_extension(this: FedoraRecord, header: HttpHeaders): string {. base .} =
  case $header["content-type"]
  of "application/xml", "text/xml":
    ".xml"
  else:
    ".bin"

method write_output(this: FedoraRecord, filename: string, contents: string, output_directory: string): string {. base .} =
  let path = fmt"{output_directory}/{filename}"
  writeFile(path, contents)
  fmt"Created {filename} at {output_directory}."

method get(this: FedoraRecord, output_directory: string): bool {. base .} =
  let response = this.client.request(this.uri, httpMethod = HttpGet)
  if response.status == "200 OK":
    let extension = this.get_extension(response.headers)
    discard this.write_output(fmt"{this.pid}{extension}", response.body, output_directory)
    true
  else:
    false
  
method modify_datastream(this: FedoraRecord, multipart_path: string): bool {. base .} =
  var data = newMultipartData()
  let entireFile = readFile(multipart_path)
  #data["uploaded_file"] = (multipart_path, "application/xml", entireFile)
  #data["output"] = "soap12"
  data["text"] = entireFile
  data["expire"] = "1m"
  data["lang"] = "text"
  #let response = this.client.request(this.uri, httpMethod = HttpPut)
  let response = this.client.putContent(this.uri, multipart=data)
  # if response.status == "200 OK":
  #   true
  # else:
  #   false
  true

method populate_results*(this: FedoraRequest, query: string): seq[string] {. base .} =
  ## Populates results for a Fedora request.
  ##
  ## Examples:
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest()
  ##    echo fedora_connection.populate_results("test")
  ##
  var new_pids: seq[string] = @[]
  var token: string = "temporary"
  var request: string = fmt"{this.base_url}/fedora/objects?query=pid%7E{query}*&pid=true&resultFormat=xml&maxResults={this.max_results}"
  var response: string = ""
  while token.len > 0:
    response = this.client.getContent(request)
    new_pids = this.grab_pids(response)
    for pid in new_pids:
      result.add(pid)
    token = this.get_token(response)
    request = fmt"{this.base_url}/fedora/objects?query=pid%7E{query}*&pid=true&resultFormat=xml&maxResults={this.max_results}&sessionToken={token}"

method harvest_metadata*(this: FedoraRequest, datastream_id="MODS"): Message {. base .} =
  ## Populates results for a Fedora request.
  ##
  ## Examples:
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest()
  ##    fedora_connection.results = fedora_connection.populate_results("test")
  ##    fedora_connection.harvest_metadata("DC")
  ##
  var pid: string
  var successes, errors: seq[string]
  var attempts: int
  var bar = newProgressBar()
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{datastream_id}/content", pid: pid)
    let response = new_record.get(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  attempts = attempts
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method update_metadata*(this: FedoraRequest, datastream_id: string, directory: string): Message {. base .} =
  var pid: string
  var successes, errors: seq[string]
  var pids_to_update: seq[(string, string)]
  var attempts: int
  pids_to_update = get_path_with_pid(directory, ".xml")
  for pid in pids_to_update:
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid[1]}/datastreams/{datastream_id}")
    let response = new_record.modify_datastream(pid[0])
    if response:
      successes.add(pid[1])
    else:
      errors.add(pid[1])
    attempts += 1
  Message(errors: errors, successes: successes, attempts: attempts)

when isMainModule:
  let fedora_connection = initFedoraRequest()
  fedora_connection.results = fedora_connection.populate_results("test")
  echo fedora_connection.update_metadata("MODS", "/home/mark/nim_projects/moldybread/experiment").successes
