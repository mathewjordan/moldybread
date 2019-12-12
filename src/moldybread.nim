import streams, strutils, xmltools, yaml/serialization, moldybreadpkg/fedora, argparse, strformat

type
  ConfigSettings = object
    ## Type to represent settings defined in config.yml
    username: string
    password: string
    base_url: string
    max_results: int
    directory_path: string
    gsearch_username: string
    gsearch_password: string

proc read_yaml_config(file_path: string): ConfigSettings =
  ## Procedure to read in a yml file and populate a ConfigSettings variable based on it.
  ##
  ## Example:
  ## .. code-block:: nim
  ##
  ##    var yaml_settings = read_yaml_config("/home/harrison/nim_projects/moldybread/config/config.yml")
  ##
  var file_stream = newFileStream(file_path)
  load(file_stream, result)
  file_stream.close()

when isMainModule:
  ## 
  ## ===========
  ## MOLDY BREAD
  ## ===========
  ##
  ## This package allows users to interact with a Fedora 3.8 repository via the CLI.
  ##
  ## The instructions here assume you are working with a compiled version of Moldy Bread. See installation instructions or package info if you are looking for
  ## something else.
  ##
  ## Defining a config.yml
  ## =====================
  ## 
  ## Make a copy of default_config.yml as config.yml and set settings appropriately.
  ## Currently, this is the only way to pass authentication information for Fedora.
  ##
  ##
  ## Command Line Parsing
  ## ====================
  ##
  ## When in doubt, use help:
  ## 
  ## .. code-block:: sh
  ## 
  ##    ./moldybread -h
  ##
  ## Harvest Metadata
  ## ================
  ##
  ## .. code-block:: sh
  ##
  ##    ./moldybread -o harvest_metadata -d MODS -n test -y /full/path/to/my/yaml/file
  ##
  ## Update Metadata
  ## ===============
  ##
  ## You can update metadata from a directory. The files must end in .xml and be named according to a PID (i.e. test:1.xml).
  ##
  ## Example layout:
  ##
  ## .. code-block:: sh
  ## 
  ##    |-- updates
  ##        |-- test:1.xml
  ##        |-- test:2.xml
  ##        |-- test:3.xml
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    ./moldybread -o update_metadata -p /home/mark/nim_projects/moldybread/updates -d MODS -y /full/path/to/my/yaml/file
  ##
  ## If your request was successful, you should see a list of PIDS that were successfully updated.
  ##
  ## **NOTE**: This operation automatically updates SOLR with Gsearch.
  ##
  var p = newParser("Moldybread"):
    help("Like whitebread but written in nim.")
    option("-o", "--operation", help="Specify operation", choices = @["harvest_metadata", "update_metadata"])
    option("-d", "--dsid", help="Specify datastream id.", default="MODS")
    option("-n", "--namespaceorpid", help="Specify containing namespace or PID.", default="")
    option("-p", "--path", help="Specify a directory path.", default="")
    option("-y", "--yaml_path", help="Specify path to config.yml", default="")
  var argv = commandLineParams()
  var opts = p.parse(argv)
  block main_control:
    try:
      var yaml_settings = read_yaml_config(opts.yaml_path)
      let fedora_connection = initFedoraRequest(url=yaml_settings.base_url, auth=(yaml_settings.username, yaml_settings.password))
      case opts.operation
      of "harvest_metadata":
        if opts.namespaceorpid != "":
          fedora_connection.results = fedora_connection.populate_results(opts.namespaceorpid)
          let test = fedora_connection.harvest_metadata(opts.dsid)
          echo test.successes
        else:
          echo "Must specify a containing namespace or pid."
      of "update_metadata":
        if opts.path != "":
          yaml_settings.directory_path = opts.path
        let operation = fedora_connection.update_metadata(opts.dsid, yaml_settings.directory_path, gsearch_auth=(yaml_settings.gsearch_username, yaml_settings.gsearch_password))
        echo operation.successes
      else:
        echo "No matching operation."
    except:
      echo fmt"Can't open yaml file at {opts.yaml_path}.  Please use th full path for now until I figure out how relative pathing works."
      break
