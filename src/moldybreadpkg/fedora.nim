import httpclient, strformat, xmltools, strutils, base64, progress, os

type
  FedoraRequest* = ref object
    ## Type to Handle Fedora requests
    base_url*: string
    results*: seq[string]
    client: HttpClient
    max_results*: int
    output_directory: string
    dc_values: string
    pid_part: string
    terms: string

  Message* = ref object
    ## Type to handle messaging
    errors*: seq[string]
    successes*: seq[string]
    attempts*: int

  FedoraRecord = ref object
    ## Type to handle Fedora Records
    client: HttpClient
    uri: string
    pid: string
  
  GsearchConnection = object
    ## Type to handle Gsearch connections
    client: HttpClient
    base_url: string

proc get_path_with_pid(path, extension: string): seq[(string, string)] =
  var
    parts_of_path: seq[string]
    pid: string
  for kind, path in walkDir(path):
    if kind == pcFile and path.contains(":"):
      parts_of_path = path.split("/")
      for value in parts_of_path:
        if value.contains(":"):
          pid = value.replace(extension, "")
      result.add((path, pid))

proc convert_dc_pairs_to_string(dc_pairs: string): string =
  var new_list: seq[string]
  for pair in dc_pairs.split(";"):
    let separated_values = pair.split(":")
    new_list.add(fmt"{separated_values[0]}%7E{separated_values[1]}")
  join(new_list, "%20")

proc initFedoraRequest*(url: string="http://localhost:8080", auth=("fedoraAdmin", "fedoraAdmin"), output_directory, dc_values, terms, pid_part="", max_results=100): FedoraRequest =
  ## Initializes new Fedora Request.
  ##
  ## Example with namespace / pid_part:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##
  ## Example with dc_values string:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(dc_values="title:Pencil;contributor:Wiley")
  ##
  let client = newHttpClient()
  client.headers["Authorization"] = "Basic " & base64.encode(auth[0] & ":" & auth[1])
  FedoraRequest(base_url: url, client: client, output_directory: output_directory, dc_values: dc_values, pid_part: pid_part, max_results: max_results, terms: terms)

proc initGsearchRequest(url: string="http://localhost:8080", auth=("fedoraAdmin", "fedoraAdmin")): GsearchConnection =
  let client = newHttpClient()
  client.headers["Authorization"] = "Basic " & base64.encode(auth[0] & ":" & auth[1])
  GsearchConnection(client: client, base_url: url)

method grab_pids(this: FedoraRequest, response: string): seq[string] {. base .} =
  let
    xml_response = Node.fromStringE(response)
    results = $(xml_response // "pid")
  for word in split(results, '<'):
    let new_word = word.replace("/", "").replace("pid>", "")
    if len(new_word) > 0:
      result.add(new_word)

method get_token(this: FedoraRequest, response: string): string {. base .} =
  let
    xml_response = Node.fromStringE(response)
    results = $(xml_response // "token")
  if results.len > 0:
    result = results.replace("<token>", "").replace("</token>", "")

method get_cursor(this: FedoraRequest, response: string): string {. base .} =
  let
    xml_response = Node.fromStringE(response)
    results = $(xml_response // "cursor")
  if results.len > 0:
    result = results.replace("<cursor>", "").replace("</cursor>", "")
  else:
    result = "No cursor"

method parse_string(this: FedoraRecord, response, element: string): seq[string] {. base .} =
  let
    xml_response = Node.fromStringE(response)
    results = $(xml_response // element)
  for node in split(results, '<'):
    let value = node.replace("/", "").replace(fmt"{element}>", "")
    if len(value) > 0:
      result.add(value)

method get_extension(this: FedoraRecord, header: HttpHeaders): string {. base .} =
  case $header["content-type"]
  of "application/xml", "text/xml", "application/rdf+xml":
    ".xml"
  else:
    ".bin"

method write_output(this: FedoraRecord, filename: string, contents: string, output_directory: string): string {. base .} =
  if not existsDir(output_directory):
    createDir(output_directory)
  let path = fmt"{output_directory}/{filename}"
  writeFile(path, contents)
  fmt"Created {filename} at {output_directory}."

method download(this: FedoraRecord, output_directory: string, suffix=""): bool {. base .} =
  let response = this.client.request(this.uri, httpMethod = HttpGet)
  if response.status == "200 OK":
    let extension = this.get_extension(response.headers)
    discard this.write_output(fmt"{this.pid}{suffix}{extension}", response.body, output_directory)
    true
  else:
    false

method get(this: FedoraRecord): bool {. base .} =
  let response = this.client.request(this.uri, httpMethod = HttpGet)
  if response.status == "200 OK":
    true
  else:
    false

method get_history(this: FedoraRecord): seq[string] {. base .} =
  let response = this.client.request(this.uri, httpMethod = HttpGet)
  if response.status == "200 OK":
    result = this.parse_string(response.body, "dsCreateDate")
  else:
    result.add("")

method check_if_page(this: FedoraRecord): bool {. base .} =
  let response = this.client.request(this.uri, httpMethod = HttpGet)
  if response.status == "200 OK":
    if response.body != "":
      false
    else:
      true
  else:
    false
  
method modify_metadata_datastream(this: FedoraRecord, multipart_path: string): bool {. base .} =
  var data = newMultipartData()
  let entireFile = readFile(multipart_path)
  data["uploaded_file"] = (multipart_path, "application/xml", entireFile)
  data["text"] = entireFile
  data["expire"] = "1m"
  data["lang"] = "text"
  try:
    discard this.client.postContent(this.uri, multipart=data)
    true
  except HttpRequestError:
    false

method put(this: FedoraRecord): bool {. base .} =
  try:
    discard this.client.request(this.uri, httpMethod = HttpPut)
    true
  except HttpRequestError:
    false

method delete(this: FedoraRecord): bool {. base .} =
  try:
    discard this.client.request(this.uri, httpMethod = HttpDelete)
    true
  except HttpRequestError:
    false

method clean_up_old_versions(this: FedoraRecord, fedora_base_url, pid, dsid: string): bool {. base .} =
  let all_versions = this.get_history()
  if len(all_versions) > 1:
    this.uri = fmt"{fedora_base_url}/fedora/objects/{pid}/datastreams/{dsid}/?startDT={all_versions[^1]}&endDT={all_versions[1]}&logMessage=DeletingOldVersions"
    discard this.delete()
    true
  else:
    false

method update_solr_record(this: GsearchConnection, pid: string): bool {. base .} =
  let request = this.client.request(fmt"{this.base_url}/fedoragsearch/rest?operation=updateIndex&action=fromPid&value={pid}", httpMethod=HttpPost)
  if request.status == "200 OK":
    # echo fmt"Successfully updated Solr Record for {pid}."
    true
  else:
    # echo fmt"{request.status}: PID {pid} failed."
    false

method populate_results*(this: FedoraRequest): seq[string] {. base .} =
  ## Populates results for a Fedora request.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    echo fedora_connection.populate_results()
  ##
  var
    new_pids: seq[string] = @[]
    token: string = "temporary"
    request, base_request: string
    response = ""
  echo "\nPopulating results.  This may take a while.\n"
  if this.dc_values != "":
    let dc_stuff = convert_dc_pairs_to_string(this.dc_values)
    request = fmt"{this.base_url}/fedora/objects?query={dc_stuff}*&pid=true&resultFormat=xml&maxResults={this.max_results}"
    base_request = fmt"{this.base_url}/fedora/objects?query={dc_stuff}*&pid=true&resultFormat=xml&maxResults={this.max_results}"
  elif this.terms != "":
    request = fmt"{this.base_url}/fedora/objects?terms={this.terms}*&pid=true&resultFormat=xml&maxResults={this.max_results}"
    base_request = fmt"{this.base_url}/fedora/objects?terms={this.terms}*&pid=true&resultFormat=xml&maxResults={this.max_results}"
  else:
    request = fmt"{this.base_url}/fedora/objects?query=pid%7E{this.pid_part}*&pid=true&resultFormat=xml&maxResults={this.max_results}"
    base_request = fmt"{this.base_url}/fedora/objects?query=pid%7E{this.pid_part}*&pid=true&resultFormat=xml&maxResults={this.max_results}"
  stdout.write("[")
  while token.len > 0:
    try:
      stdout.write("->")
      response = this.client.getContent(request)
      new_pids = this.grab_pids(response)
      for pid in new_pids:
        result.add(pid)
      token = this.get_token(response)
      request = fmt"{base_request}&sessionToken={token}"
      stdout.flushFile()
    except OSError:
      echo "Can't connect to host"
      break
  stdout.write("]")
  stdout.flushFile()

method harvest_metadata*(this: FedoraRequest, datastream_id="MODS"): Message {. base .} =
  ## Populates results for a Fedora request.
  ##
  ## Examples:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    discard fedora_connection.harvest_metadata("DC")
  ##
  var
    pid: string
    successes, errors: seq[string]
    attempts: int
    bar = newProgressBar()
  echo "\n\nHarvesting Metadata:\n"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{datastream_id}/content", pid: pid)
    let response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method determine_pages(this: FedoraRequest): seq[string] {. base .} =
  let predicate = "&predicate=info%3afedora%2ffedora-system%3adef%2frelations-external%23isMemberOf"
  var
    pid: string
    bar = newProgressBar()
  echo "\n\nChecking for Pages:\n"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/relationships?subject=info%3afedora%2f{pid}&format=turtle{predicate}", pid: pid)
    let response = new_record.check_if_page()
    if response:
      result.add(pid)
    bar.increment()
  bar.finish()

method harvest_metadata_no_pages*(this: FedoraRequest, datastream_id="MODS"): Message {. base .} =
  ## Harvests metadata for matching objects unless its content model is a page.
  ##
  ## This method requires a datastream_id and downloads the metadata record if the object does not have an isMemberOf relationship.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    discard fedora_connection.harvest_metadata_no_pages("DC")
  var
    not_pages = this.determine_pages()
    successes, errors: seq[string]
    pid: string
    attempts: int
    bar = newProgressBar()
  echo "\n\nHarvesting Metadata:\n"
  bar.start()
  for i in 1..len(not_pages):
    pid = not_pages[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{datastream_id}/content", pid: pid)
    let response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method update_metadata*(this: FedoraRequest, datastream_id, directory: string, gsearch_auth: (string, string), clean_up=false): Message {. base .} =
  ## Updates metadata records based on files in a directory.
  ##
  ## This method requires a datastream_id and a directory (use full paths for now). Files must follow the same naming convention as their
  ## PIDs and end with a .xml extension (i.e test:1.xml).
  ##
  ## Examples:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    discard fedora_connection.update_metadata("MODS", "/home/mark/nim_projects/moldybread/experiment")
  ##
  var
    successes, errors: seq[string]
    pids_to_update: seq[(string, string)]
    attempts: int
    pid: (string, string)
    bar = newProgressBar()
  let gsearch_connection = initGsearchRequest(this.base_url, gsearch_auth)
  pids_to_update = get_path_with_pid(directory, ".xml")
  echo fmt"{'\n'}{'\n'}Updating {datastream_id} based on XML files in {directory}:{'\n'}"
  bar.start()
  for i in 1..len(pids_to_update):
    pid = pids_to_update[i-1]
    var new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid[1]}/datastreams/{datastream_id}")
    let response = new_record.modify_metadata_datastream(pid[0])
    if response:
      successes.add(pid[1])
      discard gsearch_connection.update_solr_record(pid[1])
      if clean_up:
        new_record.uri = fmt"{this.base_url}/fedora/objects/{pid[1]}/datastreams/{datastream_id}/history?format=xml"
        discard new_record.clean_up_old_versions(fedora_base_url=this.base_url, pid=pid[1], dsid=datastream_id)
      successes.add(pid[1])
    else:
      errors.add(pid[1])
    attempts += 1
    bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method download_foxml*(this: FedoraRequest): Message {. base .} =
  ## Downloads the FOXML record for each object in a results set.
  ##
  ## This method downloads the foxml record for all matching objects.
  ##
  ## Example:
  ## 
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(output_directory="/home/harrison/nim_projects/moldybread/output", pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    discard fedora_connection.download_foxml().successes
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
    bar = newProgressBar()
  echo "\n\nDownloading Foxml:\n"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/export", pid: pid)
    let response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method version_datastream*(this: FedoraRequest, dsid: string, versionable: bool): Message {. base .} =
  ## Makes a datastream versioned or not versioned.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    doAssert(typeOf(fedora_connection.version_datastream("MODS", false)) == Message)
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
    bar = newProgressBar()
  echo fmt"{'\n'}{'\n'}Setting versioning on {dsid} to {versionable}.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}?versionable={versionable}")
    let response = new_record.put()
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method change_object_state*(this: FedoraRequest, state: string): Message {. base .} =
  ## Change the state of a datastream for a results set.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    doAssert(typeOf(fedora_connection.change_object_state("I")) == Message)
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
  let accepted = ["A", "I", "D"]
  echo fmt"{'\n'}{'\n'}Changing state of resluts to {state}.{'\n'}"
  if state in accepted:
    var bar = newProgressBar()
    bar.start()
    for i in 1..len(this.results):
      pid = this.results[i-1]
      let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}?state={state}")
      let response = new_record.put()
      if response:
        successes.add(pid)
      else:
        errors.add(pid)
      attempts += 1
      bar.increment()
    bar.finish()
    Message(errors: errors, successes: successes, attempts: attempts)
  else:
    echo "\nState value must be [A]ctive, [I]nactive, or [D]eleted.\n"
    Message(errors: this.results, successes: successes, attempts: len(this.results))

method purge_old_versions_of_datastream*(this: FedoraRequest, dsid: string): Message {. base .} =
  ## Purges all but the latest version of a datastream.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    doAssert(typeOf(fedora_connection.purge_old_versions_of_datastream("MODS")) == Message)
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
    bar = newProgressBar()
  echo fmt"{'\n'}{'\n'}Purging old versions of {dsid}.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}/history?format=xml")
    let response = new_record.clean_up_old_versions(fedora_base_url=this.base_url, pid=pid, dsid=dsid)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method find_objects_missing_datastream*(this: FedoraRequest, dsid: string): Message {. base .} =
  ## Lists the objects missing a specific datastream as a error.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    echo fedora_connection.find_objects_missing_datastream("RELS-INT").errors
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
    bar = newProgressBar()
  echo fmt"{'\n'}{'\n'}Finding objects missing a {dsid} datastream.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}")
    if new_record.get():
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method get_datastream_history*(this: FedoraRequest, dsid: string): Message {. base .} =
  ## Serializes the history of a datastream for a results set to disk.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(output_directory="/home/mark/nim_projects/moldybread/experiment", pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    echo fedora_connection.get_datastream_history("MODS").successes
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
    bar = newProgressBar()
  echo fmt"{'\n'}{'\n'}Getting history of {dsid} for matching objects.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}/history?format=xml", pid: pid)
    let response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method get_datastream_at_date*(this: FedoraRequest, dsid: string, date: string): Message {. base .} =
  ## Downloads the specified datastream at a specific date for all items in a result set.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(output_directory="/home/mark/nim_projects/moldybread/experiment", pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    discard fedora_connection.get_datastream_at_date("DC", "2019-12-25")
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
    bar = newProgressBar()
  echo fmt"{'\n'}{'\n'}Getting {dsid} datastream at {date} for matching objects.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}/content?asOfDateTime={date}", pid: pid)
    let response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)
