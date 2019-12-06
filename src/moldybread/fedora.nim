import httpclient, strformat, xmltools, strutils, base64, progress

type
  FedoraRequest* = ref object
    base_url*: string
    results*: seq[string]
    client: HttpClient
    max_results*: int
    output_directory: string
    authentication: (string, string)

  Message* = ref object
    errors*: seq[string]
    successes*: seq[string]
    attempts*: int

proc initFedoraRequest*(url: string="http://localhost:8080", auth=("admin", "admin")): FedoraRequest =
  ## Initializes new Fedora Request.
  let client = newHttpClient()
  client.headers["Authorization"] = "Basic " & base64.encode(auth[0] & ":" & auth[1])
  FedoraRequest(base_url: url, authentication: auth, client: client, max_results: 1, output_directory: "/home/mark/nim_projects/moldybread/sample_output")

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

method write_output(this: FedoraRequest, filename: string, contents: string): string {. base .} =
  let path = fmt"{this.output_directory}/{filename}"
  writeFile(path, contents)
  fmt"Creatred {filename} at {this.output_directory}."

method populate_results*(this: FedoraRequest, query: string): seq[string] {. base .} =
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
  var url: string
  var successes, errors: seq[string]
  var attempts: int
  var bar = newProgressBar(total= len(this.results))
  bar.start()
  for pid in this.results:
    url = fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{datastream_id}/content"
    var response = this.client.request(url, httpMethod = HttpGet)
    if response.status == "200 OK":
      successes.add(pid)
      discard this.write_output(pid, response.body)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  attempts = attempts
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

