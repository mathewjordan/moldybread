import unittest, xmltools, moldybread, moldybreadpkg/fedora, typetraits

suite "Test Public Types Initialization":
  echo "Test Public Types Initialization"

  setup:
    let fedora_connection = initFedoraRequest(
      pid_part="test",
      dc_values="title:Pencil;contributor:Wiley",
      auth=("admin", "password"),
      url="http://localhost",
      max_results=20,
      output_directory="/home/user/output")

  test "FedoraRequest Initialization":
    check(fedora_connection.base_url == "http://localhost")
    check(fedora_connection.max_results == 20)

suite "Test Fedora Connection Methods":
  echo "Fedora Connection Methods"
  
  setup:
    let fedora_connection = initFedoraRequest(pid_part="garbagenamespace")
  
  test "Population Works as Expected":
    doAssert(typeof(fedora_connection.populate_results()) is seq[string])

  test "Harvest Metadata":
    doAssert(typeof(fedora_connection.harvest_datastream("DC")) is Message)

  test "Harvest Metadata No Pages":
    doAssert(typeof(fedora_connection.harvest_datastream_no_pages("DC")) is Message)
