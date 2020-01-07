import streams, strutils, xmltools, yaml/serialization, moldybreadpkg/fedora, argparse, strformat, os

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
  ## Make a copy of default_config.yml and set settings appropriately.
  ## Currently, this is the only way to pass authentication information for Fedora and Gsearch.
  ##
  ## You can store this config file anywhere that you have read permissions.  Use the full path to the file in commands like in the examples below.
  ##
  ## Optionally, as of v0.1.2 you can avoid passing the -y flag on requests by including a directory called config with your yaml as config.yml in the path
  ## from where you are executing your command.
  ##
  ## Command Line Parsing
  ## ====================
  ##
  ## When in doubt, use help:
  ## 
  ## .. code-block:: sh
  ## 
  ##    moldybread -h
  ##
  ## Populating Results
  ## ==================
  ##
  ## Result lists can be populated in several ways.  
  ##
  ## First, if you specify dublincore fields and matching strings with the `-dc` flag, results will be populated based on their metadata records. Each DublinCore field should be separated
  ## from its matching string with a colon (:).  Each pair of fields and values should be separated with a semicolon (;). Do not include a namespace.
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -dc "title:Pencil;contributor:Wiley"
  ##
  ## Next, you can populate results based on a value in a PID or namespace with the `-n` flag.  This value will normally be the namespace, but it doesn't have to be.  It can specify any
  ## part of the pid.
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -n test
  ##
  ## Finally, you can populate results based on terms that appear anywhere in the metadata record with the `-t` flag.
  ##
  ## .. code-block:: she
  ##
  ##    moldybread -t Vancouver
  ##
  ## Harvest Datastream (including metadata)
  ## =======================================
  ##
  ## Datastreams can be harvested by supplying a datastream id (MODS by default) and a namespace. This can be used for metadata files or any other datastream.
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o harvest_datastream -d MODS -n test -y /full/path/to/my/yaml/file
  ##
  ## Datastreams can also be harvested by supplying a datastream id (MODS by default) and a string of dc fields with associated strings.
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o harvest_datastream -d MODS -dc "title:Pencil;contributor:Wiley" -y /full/path/to/my/yaml/config/file
  ##
  ## Finally, you can also harvest datastreams based on a keyword value.
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o harvest_datastream -d MODS -t Vancouver -y /full/path/to/my/yaml/config/file
  ##
  ## Harvest Datastream Unless It's a part of a Page
  ## ===============================================
  ##
  ## Most of the time, we don't want the metadata record for a page from a book collection. If we want to make sure we don't get those, we need
  ## a slightly different operation. This can be used for any datastream.
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o harvest_datastream_no_pages -d MODS -n test -y /full/path/to/my/yaml/file
  ##
  ## Download FOXML Record
  ## =====================
  ##
  ## FOXML records can be downloaded by supplying a namespace.
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o download_foxml -n test -y /full/path/to/my/yaml/file
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
  ##    moldybread -o update_metadata -p /home/mark/nim_projects/moldybread/updates -d MODS -y /full/path/to/my/yaml/file
  ##
  ## If your request was successful, you should see a list of PIDS that were successfully updated.
  ##
  ## **NOTE**: This operation automatically updates SOLR with Gsearch.
  ##
  ## Update Metadata and Delete Old Versions
  ## =======================================
  ##
  ## If you don't want to keep the old versions of the datstream you're updating, you can purge them.
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o update_metadata_and_delete_old_versions -p /home/mark/nim_projects/moldybread/updates -d MODS -y /full/path/to/my/yaml/file
  ##
  ## Version Datastream
  ## ==================
  ##
  ## Set whether a datastream should be versioned or not.
  ##
  ## **Note**: parseBool is used on the value associated wit -v / --versionable. Because of this, these values are true: `y`, `yes`, `true`, `1`, `on`.
  ## Similarly, these values are false: `n`, `no`, `false`, `0`, `off`.
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o version_datastream -n test -d MODS -v false -y /full/path/to/my/yaml/file
  ##
  ## Change Object State
  ## ===================
  ##
  ## Change the state of all objects in a result set to [`A`]ctive, [`I`]nactive, or [`D`]eleted. Defaults to `A`.
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o change_object_state -n test -s I -v false -y /full/path/to/my/yaml/file
  ##
  ## Purge Old Versions of a Datastream
  ## ==================================
  ##
  ## Purges all by the current version of a datastream.
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o purge_old_versions -n test -d MODS -y /full/path/to/my/yaml/file
  ##
  ## Find Objects Missing a Particular Datastream
  ## ============================================
  ##
  ## Finds all objects in a results set that are missing a particular datastream.
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o find_objs_missing_dsid -n test -d MODS -y /full/path/to/my/yaml/file
  ##
  ## Download Datastream Histories as XML
  ## ====================================
  ##
  ## Serializes to disk the history of a specific datatream as XML for all results in a result set.
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o get_datastream_history -n test -d RELS-EXT -y /full/path/to/my/yaml/file.yml
  ##
  ## Download Datastream at Date
  ## ===========================
  ##
  ## Serializes to disk the a datatream at a specific date for all results in a result set.
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o get_datastream_at_date -n test -d RELS-EXT -dt 2019-12-19 -y /full/path/to/my/yaml/file.yml
  ##
  ## Download All Versions of a Datastream
  ## =====================================
  ##
  ## You can download all versions of a datastream for a results set and have it serialized as pid-datestampe.extension (test:4-2020-01-07T16:18:28.742Z.xml).
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o download_all_versions -d MODS -t Vancouver -y /full/path/to/my/yaml/file.yml
  ##
  ## Validate Checksums
  ## ==================
  ##
  ## You can check whether the current checksum of a datastream for an object matches the original checksum.  If not, the objects with bad datastreams are listed:
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o validate_checksums -n test -d OBJ -y /full/path/to/my/yaml/file.yml
  ##
  ## Or, you can check whether the current checksum for all current versions of datastreams belonging to an object match the checksum of that datastream on ingest.
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o validate_checksums -n test -y /full/path/to/my/yaml/file.yml
  ##
  ## Find Unique Datastreams
  ## =======================
  ##
  ## You can get a list of unique datastreams from objects across a result set.
  ##
  ## Example command:
  ##
  ## .. code-block:: sh
  ##
  ##    moldybread -o find_distinct_datastreams -n test -y /full/path/to/my/yaml/file.yml
  ##
  const banner =     """
  __  __       _     _         ____                      _ 
 |  \/  | ___ | | __| |_   _  | __ ) _ __ ___  __ _  __| |
 | |\/| |/ _ \| |/ _` | | | | |  _ \| '__/ _ \/ _` |/ _` |
 | |  | | (_) | | (_| | |_| | | |_) | | |  __/ (_| | (_| |
 |_|  |_|\___/|_|\__,_|\__, | |____/|_|  \___|\__,_|\__,_|
                       |___/     
 
 """
  var p = newParser(fmt"Moldy Bread:  See https://markpbaggett.github.io/moldybread/moldybread.html for documentation and examples on how to use this package.{'\n'}{'\n'}"):
    help(banner)
    option("-o", "--operation", help="Specify operation", choices = @["harvest_datastream", "harvest_datastream_no_pages", "update_metadata", "update_metadata_and_delete_old_versions", "download_foxml", "version_datastream", "change_object_state", "purge_old_versions", "find_objs_missing_dsid", "get_datastream_history", "get_datastream_at_date", "validate_checksums", "find_distinct_datastreams", "download_all_versions"])
    option("-d", "--dsid", help="Specify datastream id.", default="")
    option("-n", "--namespaceorpid", help="Populate results based on namespace or PID.", default="")
    option("-dc", "--dcsearch", help="Populate results based on dc field and strings.  See docs for formatting info.", default="")
    option("-p", "--path", help="Specify a directory path.", default="")
    option("-s", "--state", help="Specify the state of an object when using change_object_state. Use A (default), I, or D.", default="A")
    option("-t", "--terms", help="Specify key words for populating results.", default="")
    option("-v", "--versionable", help="Sets if a datastream is versionable (true or false). Defaults to true.", default="true")
    option("-y", "--yaml_path", help="Specify path to config.yml", default="")
    option("-dt", "--datetime", help="Use to specify date when a date is required (yyyy-MM-dd).", default="")
  var argv = commandLineParams()
  var opts = p.parse(argv)
  var yaml_settings = read_yaml_config(fmt"{getCurrentDir()}/config/config.yml")
  block main_control:
    try:
      if opts.yaml_path != "":
        yaml_settings = read_yaml_config(opts.yaml_path)
      let fedora_connection = initFedoraRequest(
        url=yaml_settings.base_url, 
        auth=(yaml_settings.username, yaml_settings.password), 
        output_directory=yaml_settings.directory_path, 
        pid_part=opts.namespaceorpid,
        dc_values=opts.dcsearch,
        terms=opts.terms,
        max_results=yaml_settings.max_results)
      echo banner
      case opts.operation
      of "harvest_datastream":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          if opts.dsid == "":
            opts.dsid = "MODS"
          fedora_connection.results = fedora_connection.populate_results()
          let test = fedora_connection.harvest_datastream(opts.dsid)
          echo fmt"{'\n'}Successfully downloaded {len(test.successes)} record(s).  {len(test.errors)} error(s) occurred."
      of "harvest_datastream_no_pages":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          if opts.dsid == "":
            opts.dsid = "MODS"
          fedora_connection.results = fedora_connection.populate_results()
          let test = fedora_connection.harvest_datastream_no_pages(opts.dsid)
          echo fmt"{'\n'}Successfully downloaded {len(test.successes)} record(s).  {len(test.errors)} error(s) occurred."
      of "download_foxml":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          fedora_connection.results = fedora_connection.populate_results()
          let test = fedora_connection.download_foxml()
          echo fmt"{'\n'}Successfully downloaded {len(test.successes)} record(s).  {len(test.errors)} error(s) occurred."
      of "version_datastream":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          fedora_connection.results = fedora_connection.populate_results()
          try:
            let test = fedora_connection.version_datastream(opts.dsid, parseBool(opts.versionable))
            echo fmt"{'\n'}Successfully modified versioning for {len(test.successes)} record(s).  {len(test.errors)} error(s) occurred."
          except ValueError:
            echo "Must set -v or --versionable to true or false."
      of "change_object_state":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          fedora_connection.results = fedora_connection.populate_results()
          try:
            let test = fedora_connection.change_object_state(opts.state)
            echo fmt"{'\n'}Successfully modified versioning for {len(test.successes)} record(s).  {len(test.errors)} error(s) occurred."
          except ValueError:
            echo "Must set -v or --versionable to true or false."
      of "purge_old_versions":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          try:
            fedora_connection.results = fedora_connection.populate_results()
            let test = fedora_connection.purge_old_versions_of_datastream(opts.dsid)
            echo fmt"{'\n'}Purged old versions for {len(test.successes)} record(s).  Attempted but did not delete versions for {len(test.errors)} record(s)."
          except ValueError:
            echo "Must set -d or --dsid to select datastream."
      of "find_objs_missing_dsid":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          try:
            fedora_connection.results = fedora_connection.populate_results()
            let test = fedora_connection.find_objects_missing_datastream(opts.dsid)
            echo fmt"{'\n'}{len(test.errors)} were missing a {opts.dsid} datastream."
            if len(test.errors) > 0:
              echo test.errors
          except ValueError:
            echo "Must set -d or --dsid to select datastream."
      of "get_datastream_history":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          try:
            fedora_connection.results = fedora_connection.populate_results()
            let test = fedora_connection.get_datastream_history(opts.dsid)
            echo fmt"{'\n'}Successfully downloaded the history of {len(test.successes)} record(s).  {len(test.errors)} error(s) occurred."
          except ValueError:
            echo "Must set -d or --dsid to select datastream."
      of "get_datastream_at_date":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        elif opts.datetime == "":
          echo "Must specify the data / time for the datastream you wish to download."
        else:
          try:
            fedora_connection.results = fedora_connection.populate_results()
            let test = fedora_connection.get_datastream_at_date(opts.dsid, opts.datetime)
            echo fmt"{'\n'}Successfully downloaded the {opts.dsid} at {opts.datetime} of {len(test.successes)} record(s).  {len(test.errors)} error(s) occurred."
          except ValueError:
            echo "Must set -d or --dsid to select datastream."
      of "download_all_versions":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          try:
            fedora_connection.results = fedora_connection.populate_results()
            let test = fedora_connection.download_all_versions_of_datastream(opts.dsid)
            echo fmt"{'\n'}Successfully downloaded the {opts.dsid} of {test.attempts} record(s).  {len(test.errors)} error(s) occurred. {len(test.successes)} total files downloaded."
          except ValueError:
            echo "Must set -d or --dsid to select datastream."
      of "validate_checksums":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
            fedora_connection.results = fedora_connection.populate_results()
            if opts.dsid != "":
              let test = fedora_connection.validate_checksums(opts.dsid)
              echo fmt"{'\n'}{len(test.successes)} objects had valid checksums for their {opts.dsid} datastream. {len(test.errors)} objects had invalid checksums on their {opts.dsid} datastream."
              if len(test.errors) > 0:
                echo test.errors
            else:
              let test = fedora_connection.validate_checksums()
              echo fmt"{'\n'}{len(test.successes)} objects had valid checksums for their {opts.dsid} datastream. {len(test.errors)} objects had invalid checksums on their {opts.dsid} datastream."
              if len(test.errors) > 0:
                echo test.errors
      of "find_distinct_datastreams":
        if opts.namespaceorpid == "" and opts.dcsearch == "" and opts.terms == "":
          echo "Must specify how you want to populated results: -p for Pid or Namespace, -dc for dc fields and strings, or -t for keyword terms."
        else:
          fedora_connection.results = fedora_connection.populate_results()
          let result = fedora_connection.find_distinct_datastreams()
          echo fmt"{'\n'}{'\n'}There are {len(result)} unique datastreams across this result set: {'\n'}{result}"
      of "update_metadata":
        if opts.path != "":
          yaml_settings.directory_path = opts.path
        let operation = fedora_connection.update_metadata(opts.dsid, yaml_settings.directory_path, gsearch_auth=(yaml_settings.gsearch_username, yaml_settings.gsearch_password))
        echo fmt"{'\n'}Successfully updated {len(operation.successes)} {opts.dsid} record(s).  Attempted but failed to update {len(operation.errors)} record(s)."
      of "update_metadata_and_delete_old_versions":
        if opts.path != "":
          yaml_settings.directory_path = opts.path
        let operation = fedora_connection.update_metadata(opts.dsid, yaml_settings.directory_path, gsearch_auth=(yaml_settings.gsearch_username, yaml_settings.gsearch_password), clean_up=true)
        echo fmt"{'\n'}Successfully updated {len(operation.successes)} {opts.dsid} record(s).  Attempted but failed to update {len(operation.errors)} record(s)."
      else:
        echo "No matching operation."
    except RangeError:
      echo "No matching results in result set."
      break
    except:
      echo fmt"Can't open yaml file at {opts.yaml_path}.  Please use the full path for now until I figure out how relative pathing works."
      break
