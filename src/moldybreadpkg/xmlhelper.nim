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

proc get_attribute_of_element*(response, element, attribute: string): seq[string] =
  ## Terrible code to try to find matching attribute values for nodes in a string of XML.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##     let
  ##       some_xml = """<rdf:RDF xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:islandora="http://islandora.ca/ontology/relsext#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  ##         <rdf:Description rdf:about="info:fedora/test:6">
  ##         <islandora:isPageOf rdf:resource="info:fedora/test:3"></islandora:isPageOf>
  ##         <islandora:isSequenceNumber>2</islandora:isSequenceNumber>
  ##         <islandora:isPageNumber>2</islandora:isPageNumber>
  ##         <islandora:isSection>1</islandora:isSection>
  ##         <fedora:isMemberOf rdf:resource="info:fedora/test:3"></fedora:isMemberOf>
  ##         <fedora-model:hasModel rdf:resource="info:fedora/islandora:pageCModel"></fedora-model:hasModel>
  ##         <islandora:generate_ocr>TRUE</islandora:generate_ocr>
  ##         </rdf:Description>
  ##         </rdf:RDF>"""
  ##       an_element = "fedora-model:hasModel"
  ##       an_attribute = "rdf:resource"
  ##     assert get_attribute_of_element(some_xml, an_element, an_attribute) == @["info:fedora/islandora:pageCModel"]
  let
    xml_response = Node.fromStringE(response)
    results = $(xml_response // element)
  for node in split(results, '<'):
    if attribute in node:
      result.add(node.split(attribute)[1].split("\"")[1])

proc get_text_of_element_with_attribute*(response, element: string, attribute_with_value: (string, string)): seq[string] =
  ## Grabs text values of elements with associated attributes.  Use with caution.
  ##
  ## Example:
  ##
  ## .. code-block:: nim
  ##
  ##    let
  ##      some_xml = """<mods xmlns="http://www.loc.gov/mods/v3" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd">
  ##        <identifier type="local">lady-vols-basketball_2010</identifier>
  ##        <titleInfo supplied="yes"><title>Tennessee Lady Volunteers basketball media guide, 2010-2011</title></titleInfo>
  ##        <titleInfo type="alternative" displayLabel="Cover Title"><title>2010-11 Lady Vol basketball: victory lane</title></titleInfo>
  ##        <originInfo><dateIssued>2010</dateIssued><dateIssued encoding="edtf" keyDate="yes">2010</dateIssued>
  ##        <publisher>University of Tennessee, Knoxville. Department of Athletics</publisher>
  ##        <place>
  ##        <placeTerm valueURI="http://id.loc.gov/authorities/names/n79109786">Knoxville (Tenn.)</placeTerm>
  ##        </place>
  ##        </originInfo>
  ##        <abstract>Lady Volunteers basketball program from 2010.</abstract>
  ##        <physicalDescription>
  ##        <form authority="aat" valueURI="http://vocab.getty.edu/aat/300311670">booklets</form>
  ##        <extent>212 pages</extent>
  ##        </physicalDescription>
  ##        <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh85012111">
  ##        <topic>Basketball</topic>
  ##        </subject>
  ##        <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh2004010434">
  ##        <topic>College sports for women</topic>
  ##        </subject>
  ##        <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh85028338">
  ##        <topic>College sports</topic>
  ##        </subject>
  ##        <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh85012123">
  ##        <topic>Basketball players</topic>
  ##        </subject>
  ##        <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh85147485">
  ##        <topic>Women basketball players</topic>
  ##        </subject>
  ##        <subject authority="naf" valueURI="http://id.loc.gov/authorities/names/n80003889">
  ##        <name>
  ##        <namePart>University of Tennessee, Knoxville</namePart>
  ##        </name></subject>
  ##        <subject authority="naf" valueURI="http://id.loc.gov/authorities/names/n88072771"><name><namePart>Summitt, Pat Head, 1952-2016</namePart></name></subject>
  ##        <subject authority="naf" valueURI="http://id.loc.gov/authorities/names/n88072776"><name><namePart>Lady Volunteers (Basketball team)</namePart></name></subject>
  ##        <subject authority="naf" valueURI="http://id.loc.gov/authorities/names/n79109786"><geographic>Knoxville (Tenn.)</geographic><cartographics><coordinates>35.96064, -83.92074</coordinates></cartographics></subject>
  ##        <typeOfResource>text</typeOfResource>
  ##        <classification authority="lcc">LD5296.A7</classification>
  ##        <relatedItem displayLabel="Project" type="host"><titleInfo><title>University of Tennessee Lady Volunteers Basketball Media Guides</title></titleInfo></relatedItem>
  ##        <location><physicalLocation valueURI="http://id.loc.gov/authorities/names/no2014027633">University of Tennessee, Knoxville. Special Collections</physicalLocation></location>
  ##        <recordInfo><recordContentSource valueURI="http://id.loc.gov/authorities/names/n87808088">University of Tennessee, Knoxville. Libraries</recordContentSource></recordInfo>
  ##        <accessCondition type="use and reproduction" xlink:href="http://rightsstatements.org/vocab/InC/1.0/">In Copyright</accessCondition>
  ##        </mods>"""
  ##     element = "identifier"
  ##     attribute_with_value = ("type", "local")

  let
    xml_response = Node.fromStringE(response)
    results = $(xml_response // element)
  for node in split(results, '<'):
    if fmt"""{attribute_with_value[0]}="{attribute_with_value[1]}"""" in node:
      result.add(node.split('>')[1])

when isMainModule:
  let
    some_xml = """<mods xmlns="http://www.loc.gov/mods/v3" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-5.xsd">
    <identifier type="filename">yoyoyo.yo</identifier>
    <identifier type="local">lady-vols-basketball_2010</identifier>
    <titleInfo supplied="yes">
        <title>Tennessee Lady Volunteers basketball media guide, 2010-2011</title>
    </titleInfo>
    <titleInfo type="alternative" displayLabel="Cover Title">
        <title>2010-11 Lady Vol basketball: victory lane</title>
    </titleInfo>
    <originInfo>
        <dateIssued>2010</dateIssued>
        <dateIssued encoding="edtf" keyDate="yes">2010</dateIssued>
        <publisher>University of Tennessee, Knoxville. Department of Athletics</publisher>
        <place>
          <placeTerm valueURI="http://id.loc.gov/authorities/names/n79109786">Knoxville (Tenn.)</placeTerm>
        </place>
    </originInfo>
    <abstract>Lady Volunteers basketball program from 2010.</abstract>
    <physicalDescription>
        <form authority="aat" valueURI="http://vocab.getty.edu/aat/300311670">booklets</form>
        <extent>212 pages</extent>
    </physicalDescription>
    <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh85012111">
        <topic>Basketball</topic>
    </subject>
    <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh2004010434">
        <topic>College sports for women</topic>
    </subject>
    <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh85028338">
        <topic>College sports</topic>
    </subject>
    <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh85012123">
        <topic>Basketball players</topic>
    </subject>
    <subject authority="lcsh" valueURI="http://id.loc.gov/authorities/subjects/sh85147485">
        <topic>Women basketball players</topic>
    </subject>
    <subject authority="naf" valueURI="http://id.loc.gov/authorities/names/n80003889">
        <name>
          <namePart>University of Tennessee, Knoxville</namePart>
        </name>
    </subject>
    <subject authority="naf" valueURI="http://id.loc.gov/authorities/names/n88072771">
        <name>
          <namePart>Summitt, Pat Head, 1952-2016</namePart>
        </name>
    </subject>
    <subject authority="naf" valueURI="http://id.loc.gov/authorities/names/n88072776">
        <name>
          <namePart>Lady Volunteers (Basketball team)</namePart>
        </name>
    </subject>
    <subject authority="naf" valueURI="http://id.loc.gov/authorities/names/n79109786">
        <geographic>Knoxville (Tenn.)</geographic>
        <cartographics>
          <coordinates>35.96064, -83.92074</coordinates>
        </cartographics>
    </subject>
    <typeOfResource>text</typeOfResource>
    <classification authority="lcc">LD5296.A7</classification>
    <relatedItem displayLabel="Project" type="host">
        <titleInfo>
          <title>University of Tennessee Lady Volunteers Basketball Media Guides</title>
        </titleInfo>
    </relatedItem>
    <location>
        <physicalLocation valueURI="http://id.loc.gov/authorities/names/no2014027633">University of Tennessee, Knoxville. Special Collections</physicalLocation>
    </location>
    <recordInfo>
        <recordContentSource valueURI="http://id.loc.gov/authorities/names/n87808088">University of Tennessee, Knoxville. Libraries</recordContentSource>
    </recordInfo>
    <accessCondition type="use and reproduction" xlink:href="http://rightsstatements.org/vocab/InC/1.0/">In Copyright</accessCondition>
    </mods>"""
    an_element = "identifier"
    attribute_and_value = ("type", "local")
  echo get_text_of_element_with_attribute(some_xml, an_element, attribute_and_value)
  
