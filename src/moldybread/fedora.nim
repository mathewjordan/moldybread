import httpclient, strformat, xmltools, strutils, base64, progress

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

proc initFedoraRequest*(url: string="http://localhost:8080", auth=("admin", "admin")): FedoraRequest =
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
  of "application/xml":
    ".xml"
  of "text/xml":
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

method populate_results*(this: FedoraRequest, query: string): seq[string] {. base .} =
  ## Populates results for a Fedora request.
  ##
  ## Examples:
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest()
  ##    echo fedora_connection.populate_results()
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
  ##    fedora_connection.populate_results()
  ##    fedora_connection.harvest_metadata("DC")
  ##
  var url, pid: string
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
