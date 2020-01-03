import unittest, xmltools, moldybread, moldybreadpkg/fedora, typetraits, moldybreadpkg/xmlhelper

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

suite "Test XML Helper":
  echo "XML Helper Tests"

  setup:
    let
      some_xml = """<?xml version="1.0" encoding="UTF-8"?><datastreamProfile  xmlns="http://www.fedora.info/definitions/1/0/management/"  xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/1/0/management/ http://www.fedora.info/definitions/1/0/datastreamProfile.xsd" pid="test:9" dsID="MODS"><dsLabel>MODS Record</dsLabel>
      <dsVersionID>MODS.5</dsVersionID>
      <dsCreateDate>2019-12-19T02:50:24.322Z</dsCreateDate>
      <dsState>A</dsState>
      <dsMIME>application/xml</dsMIME>
      <dsFormatURI></dsFormatURI>
      <dsControlGroup>X</dsControlGroup>
      <dsSize>178</dsSize>
      <dsVersionable>true</dsVersionable>
      <dsInfoType></dsInfoType>
      <dsLocation>test:9+MODS+MODS.5</dsLocation>
      <dsLocationType></dsLocationType>
      <dsChecksumType>SHA-1</dsChecksumType>
      <dsChecksum>f2e60f8860158d6d175bdd3c2710928c79a5d024</dsChecksum>
      <dsChecksumValid>true</dsChecksumValid>
      </datastreamProfile>
      """
      an_element = "dsChecksumValid"

  test "parse_data works as expected":
    assert parse_data(some_xml, an_element) == @["true"]
