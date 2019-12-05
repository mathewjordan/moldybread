import streams, strutils, xmltools, yaml/serialization, moldybread/fedora

type
  ConfigSettings* = object
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
  var yaml_settings = read_yaml_config("/home/mark/nim_projects/moldybread/config/config.yml")
  let fedora_connection = initFedoraRequest(url=yaml_settings.base_url, auth=(yaml_settings.username, yaml_settings.password))
  fedora_connection.results = fedora_connection.populate_results("test")
  let test = fedora_connection.harvest_metadata("MODS")
  echo test.successes
