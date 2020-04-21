import httpclient, strformat, xmltools, strutils, base64, progress, os, xmlhelper, times, sequtils, math, xacml

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
    new_list.add(fmt"{separated_values[0]}%7E%27{separated_values[1]}%27")
  join(new_list, "%20")

proc progress_prep(size: int): seq[int] =
  for i in 1..100:
    result.add(i*int(ceil(size/100)))

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

proc process_versions*(pids_and_versions: seq[(string, int)], version_target: int, operation: string): seq[string] =
  ## Helper function to process pids and versions against user expectations.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    var versions = @[("abc:1", 1), ("abc:2", 2), ("abc:3", 1)]
  ##    assert process_versions(versions, 2, "==") == @["abc:2"]
  ##
  for pair in pids_and_versions:
    case operation
    of "==":
      if pair[1] == version_target:
        result.add(pair[0])
    of "!=":
      if pair[1] != version_target:
        result.add(pair[0])
    of ">=":
      if pair[1] >= version_target:
        result.add(pair[0])
    of "<=":
      if pair[1] <= version_target:
        result.add(pair[0])
    of ">":
      if pair[1] > version_target:
        result.add(pair[0])
    of "<":
      if pair[1] < version_target:
        result.add(pair[0])
    else:
      result.add("Invalid operation.")
      return
  return

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
  of "text/plain":
    ".txt"
  of "text/html":
    ".html"
  of "application/pdf":
    ".pdf"
  of "image/tiff":
    ".tif"
  of "image/jp2":
    ".jp2"
  of "image/jpeg":
    ".jpg"
  else:
    ".bin"

method content_model_lookup(this: FedoraRecord, pid: string): string {. base .} =
  case pid
  of "islandora:pageCModel":
    "page"
  of "islandora:sp_pdf":
    "pdf"
  of "islandora:entityCModel":
    "entity"
  of "islandora:bookCModel":
    "book"
  of "islandora:newspaperCModel":
    "newspaper"
  of "islandora:eventCModel":
    "event"
  of "islandora:placeCModel":
    "place"
  of "islandora:sp_basic_image":
    "basic image"
  of "islandora:newspaperPageCModel":
    "newspaper page"
  of "islandora:sp-audioCModel":
    "audio file"
  of "islandora:sp_disk_image":
    "disk image"
  of "islandora:personCModel":
    "person"
  of "islandora:sp_videoCModel":
    "video"
  of "islandora:newspaperIssueCModel":
    "newspaper issue"
  of "islandora:collectionCModel":
    "collection"
  of "islandora:organizationCModel":
    "organization"
  of "islandora:sp_web_archive":
    "web archive"
  of "islandora:compoundCModel":
    "compound object"
  of "islandora:sp_large_image_cmodel":
    "large image"
  of "ir:citationCModel":
    "citation"
  of "ir:thesisCModel":
    "thesis"
  else:
    "unknown"

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

method get_content_model(this: FedoraRecord): string {. base .} =
  let response = this.client.request(this.uri, httpMethod = HttpGet)
  if response.status == "200 OK":
    this.content_model_lookup(get_attribute_of_element(response.body, "fedora-model:hasModel", "rdf:resource")[0].replace("info:fedora/", ""))
  else:
    "not found"

method audit_responsibility(this: FedoraRecord, username: string): bool {. base .} =
  let response = this.client.request(this.uri, httpMethod = HttpGet)
  result = false
  if response.status == "200 OK":
    if username in this.parse_string(response.body, "audit:responsibility"):
      result = true

method get(this: FedoraRecord): string {. base .} =
  let response = this.client.request(this.uri, httpMethod = HttpGet)
  if response.status == "200 OK":
    response.body
  else:
    ""

method get_history(this: FedoraRecord): seq[string] {. base .} =
  let response = this.client.request(this.uri, httpMethod = HttpGet)
  if response.status == "200 OK":
    result = this.parse_string(response.body, "dsCreateDate")
  else:
    echo this.uri
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

method is_it_versioned(this: FedoraRecord): bool {. base .} =
  let history = this.client.request(this.uri, httpMethod = HttpGet)
  if history.status == "200 OK":
    parseBool(this.parse_string(history.body, "dsVersionable")[0])
  else:
    true
  
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
  echo "\nFinding matching objects.  This may take a while.\n"
  if this.dc_values != "":
    let dc_stuff = convert_dc_pairs_to_string(this.dc_values)
    request = fmt"{this.base_url}/fedora/objects?query={dc_stuff}&pid=true&resultFormat=xml&maxResults={this.max_results}".replace(" ", "%20")
    base_request = fmt"{this.base_url}/fedora/objects?query={dc_stuff}&pid=true&resultFormat=xml&maxResults={this.max_results}".replace(" ", "%20")
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

method harvest_datastream*(this: FedoraRequest, datastream_id="MODS"): Message {. base .} =
  ## Populates results for a Fedora request.
  ##
  ## Examples:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    discard fedora_connection.harvest_datastream("DC")
  ##
  var
    pid: string
    successes, errors: seq[string]
    attempts: int
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Harvesting {datastream_id} datastreams:{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{datastream_id}/content", pid: pid)
      response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    if i in ticks:
      bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method determine_pages(this: FedoraRequest): seq[string] {. base .} =
  let predicate = "&predicate=info%3afedora%2ffedora-system%3adef%2frelations-external%23isMemberOf"
  var
    pid: string
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo "\n\nChecking for Pages:\n"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/relationships?subject=info%3afedora%2f{pid}&format=turtle{predicate}", pid: pid)
      response = new_record.check_if_page()
    if response:
      result.add(pid)
    if i in ticks:
      bar.increment()
  bar.finish()

method harvest_datastream_no_pages*(this: FedoraRequest, datastream_id="MODS"): Message {. base .} =
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
  ##    discard fedora_connection.harvest_datastream_no_pages("DC")
  var
    not_pages = this.determine_pages()
    successes, errors: seq[string]
    pid: string
    attempts: int
    bar = newProgressBar(total=len(not_pages), step=int(ceil(len(not_pages)/100)))
  let ticks = progress_prep(len(not_pages))
  echo fmt"{'\n'}{'\n'}Harvesting {datastream_id} datastreams:{'\n'}"
  bar.start()
  for i in 1..len(not_pages):
    pid = not_pages[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{datastream_id}/content", pid: pid)
      response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    if i in ticks:
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
    pids_to_update: seq[(string, string)] = get_path_with_pid(directory, ".xml")
    attempts: int
    pid: (string, string)
    bar = newProgressBar(total=len(pids_to_update), step=int(ceil(len(pids_to_update)/100)))
  let
    ticks = progress_prep(len(pids_to_update))
    gsearch_connection = initGsearchRequest(this.base_url, gsearch_auth)
  echo fmt"{'\n'}{'\n'}Updating {datastream_id} based on XML files in {directory}:{'\n'}"
  bar.start()
  for i in 1..len(pids_to_update):
    pid = pids_to_update[i-1]
    let
      history = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid[1]}/datastreams/{datastream_id}/history?format=xml")
      versioned = history.is_it_versioned()
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid[1]}/datastreams/{datastream_id}?versionable={versioned}")
      response = new_record.modify_metadata_datastream(pid[0])
    if response:
      discard gsearch_connection.update_solr_record(pid[1])
      if clean_up == true:
        new_record.uri = fmt"{this.base_url}/fedora/objects/{pid[1]}/datastreams/{datastream_id}/history?format=xml"
        discard new_record.clean_up_old_versions(fedora_base_url=this.base_url, pid=pid[1], dsid=datastream_id)
      successes.add(pid[1])
    else:
      errors.add(pid[1])
    attempts += 1
    if i in ticks:
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
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo "\n\nDownloading Foxml:\n"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/export", pid: pid)
      response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    if i in ticks:
      bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method audit_responsibility*(this: FedoraRequest, username: string): Message {. base .} =
  ## Looks for objects created or modified by a specific user.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    echo fedora_connection.audit_responsibility("fedoraAdmin").successes
  ##
  var
    attempts: int
    pid: string
    successes: seq[string]
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Auditing responsibility for {username}.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/export", pid: pid)
      response = new_record.audit_responsibility(username)
    if response == true:
      successes.add(pid)
    attempts += 1
    if i in ticks:
      bar.increment()
  bar.finish()
  Message(successes: successes, attempts: attempts)

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
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Setting versioning on {dsid} to {versionable}.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}?versionable={versionable}")
      response = new_record.put()
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    if i in ticks:
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
  echo fmt"{'\n'}{'\n'}Changing state of results to {state}.{'\n'}"
  if state in accepted:
    var
      bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
    let
      ticks = progress_prep(len(this.results))
    bar.start()
    for i in 1..len(this.results):
      pid = this.results[i-1]
      let
        new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}?state={state}")
        response = new_record.put()
      if response:
        successes.add(pid)
      else:
        errors.add(pid)
      attempts += 1
      if i in ticks:
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
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Purging old versions of {dsid}.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}/history?format=xml")
      response = new_record.clean_up_old_versions(fedora_base_url=this.base_url, pid=pid, dsid=dsid)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    if i in ticks:
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
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Finding objects missing a {dsid} datastream.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}")
    if new_record.get() != "":
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    if i in ticks:
      bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method get_datastreams*(this: FedoraRequest, profiles=true, as_of_date=getTime()): seq[(string, seq[TaintedString])] {. base .} =
  ## Returns a sequence of tuples with the pid and a sequence of datastreams that belong to it.
  ##
  ## Optionally, you can specify whether you want an entire datastream profile returned (defaults to true) or just the datastream id and
  ## a date for which you want to base the query on (defaults to now).  Use `yyyy-MM-dd` or `yyyy-MM-ddTHH:mm:ssZ`.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(output_directory="/home/mark/nim_projects/moldybread/experiment", pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    echo fedora_connection.get_datastreams(profiles=true)
  ##
  var
    attempts: int
    pid: string
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}Finding all datastreams for objects in result set."
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams?profiles={profiles}&asOfDateTime={as_of_date}")
    if new_record.get() != "":
      let 
        datastreams = parse_data(new_record.get(), "datastreamProfile").filterIt(it.startsWith("datastreamProfile")).mapIt($it.split(" ")[1].split("=")[1].replace("\"", ""))
      result.add((pid, datastreams))
    attempts+=1
    if i in ticks:
      bar.increment()
  bar.finish()

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
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Getting history of {dsid} for matching objects.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}/history?format=xml", pid: pid)
      response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    if i in ticks:
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
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Getting {dsid} datastream at {date} for matching objects.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}/content?asOfDateTime={date}", pid: pid)
      response = new_record.download(this.output_directory)
    if response:
      successes.add(pid)
    else:
      errors.add(pid)
    attempts += 1
    if i in ticks:
      bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method download_all_versions_of_datastream*(this: FedoraRequest, dsid: string): Message {. base .} =
  ## Downloads all versions of a specific datastream and names it as pid-datetime.extension (test:223-2020-01-07T17:25:32.085Z.xml).
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(output_directory="/home/mark/nim_projects/moldybread/experiment", pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    echo fedora_connection.download_all_versions_of_datastream("MODS").successes
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Downloading all {dsid} datastreams for matching objects.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      history = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}/history?format=xml")
      versions = history.get_history()
    for version in versions:
      let
        new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}/content?asOfDateTime={version}", pid: pid)
        response = new_record.download(this.output_directory, suffix=fmt"-{version}")
      if response:
        successes.add(pid)
      else:
        errors.add(pid)
    attempts += 1
    if i in ticks:
      bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method validate_checksums*(this: FedoraRequest, dsid: string): Message {. base .} =
  ## Checks if the current checksum of datastreams in a result set matches the checksum of the same datastream on ingest.
  ##
  ## If so, the check is considered a success.  If not, the check is an error.  If a datastream is not found for an object, niether a success or error is registered.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(output_directory="/home/mark/nim_projects/moldybread/experiment", pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    echo fedora_connection.validate_checksums("MODS").successes
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Validating checksums for the {dsid} datastream for matching objects.{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}?validateChecksum=true&format=xml", pid: pid)
      response = new_record.get()
    if response != "" and parseBool(parse_data(response, "dsChecksumValid")[0]):
      successes.add(pid)
    elif response != "" and parseBool(parse_data(response, "dsChecksumValid")[0]) == false:
      errors.add(pid)
    attempts += 1
    if i in ticks:
      bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method validate_checksums*(this: FedoraRequest): Message {. base .} =
  ## Checks if the current checksum of all datastreams belonging to a particular object matches the checksum of the datastream when it was ingested.
  ##
  ## If the validation is confirmed, the pid and datastream are appended to the successes sequence of the result Message.
  ## If the validation fails, the pid and datastream are appended to the errors sequence of the result Message.
  ##
  ## NOTE: By design, this method only checks the current version of the datastream and ignores previous versions.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(output_directory="/home/mark/nim_projects/moldybread/experiment", pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    echo fedora_connection.validate_checksums().errors
  ##
  var
    successes, errors: seq[string]
    attempts: int
    pid: string
  let
    datastream_report = this.get_datastreams()
    ticks = progress_prep(len(datastream_report))
  var
    bar = newProgressBar(total=len(datastream_report), step=int(ceil(len(datastream_report)/100)))
  echo fmt"{'\n'}{'\n'}Validating checksums for each datastream for matching objects.{'\n'}"
  bar.start()
  for i in 1..len(datastream_report):
    for datastream in datastream_report[i-1][1]:
      let
        new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{datastream_report[i-1][0]}/datastreams/{datastream}?validateChecksum=true&format=xml", pid: pid)
        response = new_record.get()
      if response != "" and parseBool(parse_data(response, "dsChecksumValid")[0]):
        successes.add(fmt"{datastream_report[i-1][0]}--{datastream}")
      elif response != "" and parseBool(parse_data(response, "dsChecksumValid")[0]) == false:
        errors.add(fmt"{datastream_report[i-1][0]}--{datastream}")
        attempts += 1
    if i in ticks:
      bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method find_distinct_datastreams*(this: FedoraRequest): seq[string] {. base .} =
  ## Filters distinct datastreams from all objects in a result set.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(output_directory="/home/mark/nim_projects/moldybread/experiment", pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    echo fedora_connection.find_distinct_datastreams()
  ##
  let
    datastream_report = this.get_datastreams()
    ticks = progress_prep(len(datastream_report))
  var
    bar = newProgressBar(total=len(datastream_report), step=int(ceil(len(datastream_report)/100)))
  echo "\n\nFiltering unique datastreams from result set.\n"
  bar.start()
  for i in 1..len(datastream_report):
    for datastream in datastream_report[i-1][1]:
      if datastream notin result:
        result.add(datastream)
    if i in ticks:
      bar.increment()
  bar.finish()

method get_content_models*(this: FedoraRequest): seq[(string, string)] {. base .} =
  ## Returns a sequence of tuples with pids with a human readable version of its content model.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(output_directory="/home/mark/nim_projects/moldybread/experiment", pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    echo fedora_connection.get_content_models()
  ##
  var
    pid: string
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let
    ticks = progress_prep(len(this.results))
  echo "\n\nGetting Content Models of results set.\n"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/RELS-EXT/content", pid: pid)
      content_model = new_record.get_content_model()
    result.add((pid, content_model))
    if i in ticks:
      bar.increment()
  bar.finish()

method update_solr_with_gsearch*(this: FedoraRequest, gsearch_auth: (string, string)): Message {. base .} =
  ## Updates solr records for objects with gsearch.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    discard fedora_connection.update_solr_with_gsearch()
  ##
  var
    successes, errors: seq[string]
    attempts: int
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let
    ticks = progress_prep(len(this.results))
    gsearch_connection = initGsearchRequest(this.base_url, gsearch_auth)
  echo fmt"{'\n'}{'\n'}Updating Solr Documents:{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    let x = gsearch_connection.update_solr_record(this.results[i-1])
    if x:
      successes.add(this.results[i-1])
    else:
      errors.add(this.results[i-1])
    attempts += 1
    if i in ticks:
      bar.increment()
  bar.finish()
  Message(errors: errors, successes: successes, attempts: attempts)

method count_versions_of_datastream*(this: FedoraRequest, dsid: string): seq[(string, int)] {. base .}=
  ## Returns pids with the total number of versions a specified datastream has
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let fedora_connection = initFedoraRequest(pid_part="test")
  ##    fedora_connection.results = fedora_connection.populate_results()
  ##    discard fedora_connection.count_versions_of_datastream("MODS")
  ##
  var
    attempts: int
    pid: string
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let
    ticks = progress_prep(len(this.results))
  echo fmt"{'\n'}{'\n'}Counting number of {dsid} versions in this set:{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      versions = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/{dsid}/history?format=xml", pid: pid)
    attempts += 1
    result.add((pid, len(versions.get_history)))
    if i in ticks:
      bar.increment()
  bar.finish()

method find_xacml_restrictions(this: FedoraRequest): seq[(string, seq[XACMLRule])] {. base .} =
  ## Returns all XACML rules for objects in a set.
  ##
  ## Example:
  ##
  var
    pid: string
    bar = newProgressBar(total=len(this.results), step=int(ceil(len(this.results)/100)))
  let
    ticks = progress_prep(len(this.results))
  echo fmt"Finding XACML restrictions for all objects in set:{'\n'}"
  bar.start()
  for i in 1..len(this.results):
    pid = this.results[i-1]
    let
      new_record = FedoraRecord(client: this.client, uri: fmt"{this.base_url}/fedora/objects/{pid}/datastreams/POLICY/content", pid: pid)
      response = new_record.get()
    if response != "":
      result.add((pid, parse_rules(response)))
    if i in ticks:
      bar.increment()
  bar.finish()
    