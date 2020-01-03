import xmltools, strutils, strformat

proc parse_data*(response, element: string): seq[string] =
  ## Takes XML as a string and an element name and returns the text nodes of each element as a sequence of strings.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let
  ##          some_xml = """<?xml version="1.0" encoding="UTF-8"?><datastreamProfile  xmlns="http://www.fedora.info/definitions/1/0/management/"  xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.fedora.info/definitions/1/0/management/ http://www.fedora.info/definitions/1/0/datastreamProfile.xsd" pid="test:9" dsID="MODS"><dsLabel>MODS Record</dsLabel>
  ##          <dsVersionID>MODS.5</dsVersionID>
  ##          <dsCreateDate>2019-12-19T02:50:24.322Z</dsCreateDate>
  ##          <dsState>A</dsState>
  ##          <dsMIME>application/xml</dsMIME>
  ##          <dsFormatURI></dsFormatURI>
  ##          <dsControlGroup>X</dsControlGroup>
  ##          <dsSize>178</dsSize>
  ##          <dsVersionable>true</dsVersionable>
  ##          <dsInfoType></dsInfoType>
  ##          <dsLocation>test:9+MODS+MODS.5</dsLocation>
  ##          <dsLocationType></dsLocationType>
  ##          <dsChecksumType>SHA-1</dsChecksumType>
  ##          <dsChecksum>f2e60f8860158d6d175bdd3c2710928c79a5d024</dsChecksum>
  ##          <dsChecksumValid>true</dsChecksumValid>
  ##          </datastreamProfile>
  ##          """
  ##      an_element = "dsChecksumValid"
  ##    assert parsedata(some_xml, an_element) == @["true"]
  ##
  let
    xml_response = Node.fromStringE(response)
    results = $(xml_response // element)
  for node in split(results, '<'):
    let value = node.replace("/", "").replace(fmt"{element}>", "")
    if len(value) > 0:
      result.add(value)
