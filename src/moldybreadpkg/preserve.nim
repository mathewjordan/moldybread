import httpclient, base64, strformat, xmlhelper, strutils, yaml/serialization, streams, os

type
  PreservationObject* = ref object
    ## Handles Preservation Object
    pid*, content_model, parent, base_uri*, external_relationships: string
    dsid_and_checksum: seq[(string, string)]
    client*: HttpClient
  
  ContentModel = object
    dsids: seq[string]

  PreservationSettings = object
    ## Type to represent preservation settings
    book, page, large_image, basic_image: ContentModel
  
  AccessError* = object of Exception

  LookupError* = object of Exception

proc read_yaml_config(file_path: string): PreservationSettings =
  var file_stream = newFileStream(file_path)
  load(file_stream, result)
  file_stream.close()

proc content_model_translator(content_model: string): string = 
  case content_model
  of "islandora:bookCModel":
    "book"
  of "islandora:pageCModel":
    "page"
  of "islandora:sp_large_image_cmodel":
    "large_image"
  of "islandora:sp_basic_image":
    "basic_image"
  else:
    raise newException(LookupError, fmt"{content_model} could not be translated.")

proc get_extension(header: HttpHeaders): string =
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

proc serialize_file(filename, contents, output_directory: string) =
  if not existsDir(output_directory):
    createDir(output_directory)
  let path = fmt"{output_directory}/{filename}"
  writeFile(path, contents)

proc initPreservationObject*(pid, uri: string, auth: (string, string)): PreservationObject =
  let client = newHttpClient()
  client.headers["Authorization"] = "Basic " & base64.encode(auth[0] & ":" & auth[1])
  PreservationObject(client: client, base_uri: uri, pid: pid)

method get_external_relationships*(this: PreservationObject): string {. base .} =
  let
    request = this.client.request(fmt"{this.base_uri}/fedora/objects/{this.pid}/datastreams/RELS-EXT/content", httpMethod = HttpGet)
  if request.status == "200 OK":
    request.body
  else:
    raise newException(AccessError, fmt"The request for the content model of {this.pid} failed with {request.status}.")

method get_checksum(this: PreservationObject, dsid: string): string {. base .} =
  let
    request = this.client.request(fmt"{this.base_uri}/fedora/objects/{this.pid}/datastreams/{dsid}?validateChecksum=false&format=xml", httpMethod = HttpGet)
  if request.status == "200 OK":
    parse_data(request.body, "dsChecksum")[0]
  else:
    raise newException(AccessError, fmt"The request for the {dsid} datastream on {this.pid} failed with {request.status}.")

method get_preservation_datastreams(this: PreservationObject, settings: PreservationSettings): seq[string] {. base .} =
  case this.content_model
  of "book":
    settings.book.dsids
  of "page":
    settings.page.dsids
  of "large_image":
    settings.large_image.dsids
  of "basic_image":
    settings.basic_image.dsids
  else:
    raise newException(LookupError, fmt"Unable to retrieve relevant preservation datastreams for {this.content_model}.")

method get_content_model(this: PreservationObject): string {. base .} =
  content_model_translator(get_attribute_of_element(this.external_relationships, "fedora-model:hasModel", "rdf:resource")[0].replace("info:fedora/", ""))

method get_parent_and_page_number(this: PreservationObject): (string, string) {. base .} =
  (
    get_attribute_of_element(this.external_relationships, "islandora:isPageOf", "rdf:resource")[0].replace("info:fedora/", ""),
    parse_data(this.external_relationships, "islandora:isPageNumber")[0]
  )
  
method download(this: PreservationObject, datastream: string): bool {. base .} =
  let request = this.client.request(fmt"{this.base_uri}/fedora/objects/{this.pid}/datastreams/{datastream}/content")
  if request.status == "200 OK":
    if this.content_model == "page":
      let rels = this.get_parent_and_page_number()
      serialize_file(fmt"{rels[0]}-page{rels[1]}{get_extension(request.headers)}", request.body, "/home/mark/nim_projects/moldybread/experiment")
    else:
      serialize_file(fmt"{this.pid}{get_extension(request.headers)}", request.body, "/home/mark/nim_projects/moldybread/experiment")
    true
  else:
    raise newException(AccessError, fmt"Could not download {this.pid}'s {datastream} datastream.")

method preserve*(this: PreservationObject): seq[(string, string)] {. base .} =
  let preservation_settings = read_yaml_config(fmt"{getCurrentDir()}/config/preserve.yml")
  this.external_relationships = this.get_external_relationships()
  this.content_model = this.get_content_model()
  for datastream in this.get_preservation_datastreams(preservation_settings):
    this.dsid_and_checksum.add((datastream, this.get_checksum(datastream)))
    discard this.download(datastream)
  this.dsid_and_checksum
