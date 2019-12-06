import streams, strutils, xmltools, yaml/serialization, moldybread/fedora, argparse

type
  ConfigSettings = object
    username: string
    password: string
    base_url: string
    max_results: int
    output_directory: string

proc read_yaml_config(file_path: string): ConfigSettings =
  var file_stream = newFileStream(file_path)
  load(file_stream, result)
  file_stream.close()

when isMainModule:
  var p = newParser("Moldybread"):
    help("Like whitebread but written in nim.")
    option("-o", "--operation", help="Specify operation", choices = @["harvest_metadata"])
    option("-d", "--dsid", help="Specify datastream id.", default="MODS")
    option("-n", "--namespaceorpid", help="Specify containing namespace or PID.", default="")
  var argv = commandLineParams()
  var opts = p.parse(argv)
  var yaml_settings = read_yaml_config("/home/mark/nim_projects/moldybread/config/config.yml")
  let fedora_connection = initFedoraRequest(url=yaml_settings.base_url, auth=(yaml_settings.username, yaml_settings.password))
  case opts.operation
  of "harvest_metadata":
    if opts.namespaceorpid != "":
      fedora_connection.results = fedora_connection.populate_results(opts.namespaceorpid)
      let test = fedora_connection.harvest_metadata(opts.dsid)
      echo test.successes
    else:
      echo "Must specify a containing namespace or pid."
  else:
    echo "No matching operation."
