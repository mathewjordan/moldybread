import unittest, xmltools, moldybread

suite "Test Population Procedures":
  echo "Test Population Procedures for Fedora Connections"

  setup:
    let xml: string = """
      <?xml version="1.0" encoding="UTF-8"?><result xmlns="http://www.fedora.info/definitions/1/0/types/" xmlns:types="http://www.fedora.info/definitions/1/0/types/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
      xsi:schemaLocation="http://www.fedora.info/definitions/1/0/types/ http://localhost:8080/fedora/schema/findObjects.xsd"><listSession>
      <token>cdbe076c0c32abc9e82478da7ec52dbc</token><cursor>0</cursor><expirationDate>2019-11-22T02:04:39.005Z</expirationDate></listSession><resultList><objectFields>
      <pid>test:4</pid></objectFields><objectFields><pid>test:5</pid></objectFields></resultList></result>"""
  
  test "get_token":
    check("cdbe076c0c32abc9e82478da7ec52dbc" == get_token(xml))

  test "grab_pids":
    check(@["test:4", "test:5"] == grab_pids(xml))
