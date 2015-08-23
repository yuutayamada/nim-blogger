# my test file to get oauth2 for google Blogger
# https://developers.google.com/identity/protocols/OAuth2InstalledApp
# use "installed applications"s flow
# enable Blogger API v3 https://developers.google.com/apis-explorer/?hl=en_US#p/blogger/v3/

import
  strutils, httpclient, strtabs, json, os, marshal, logging, parseopt2

from lib/googleapi as gapi import nil
from lib/commandutil as util import nil

# NOTE: Need to initialize to compile
var params: gapi.Params = gapi.Params(
  access_token: "", token_type: "", refresh_token: "", authHeader: "",
  client_id: getEnv("GOOGLE_API_CLIENT_ID"),
  client_secret: getEnv("GOOGLE_API_CLIENT_SECRET"),
  configFile: os.joinPath(getEnv("XDG_CONFIG_HOME") / "nimbloggercl", "config"),
  sourceFile: "",
  title: "",
  labels: ""
)

proc setParams(p: var gapi.Params) =
  ## Set basic parameters
  var confFromFile: JsonNode = parseFile(params.configFile)
  p.access_token  = confFromFile["body"]["access_token"].str
  p.token_type    = confFromFile["body"]["token_type"].str
  p.refresh_token = confFromFile["body"]["refresh_token"].str
  p.authHeader    = "Authorization: " & p.token_type & " " & p.access_token

proc cmdOptionParse(kind: CmdLineKind, key, val: TaintedString, cmd:
  var string, p: var gapi.Params) =
  block exit:
    case kind
    of cmdShortOption, cmdLongOption:
      case key
      of "h", "help":
        util.showHelp()
        break exit
      of "f", "file":
        params.sourceFile = val.string
      of "t", "title":
        params.title = val.string
      of "n", "blogname":
        params.blogname = val.string
      of "l", "labels":
        params.labels = val.string
      of "c":      params.configFile    = val.string
      of "id":     params.client_id     = val.string
      of "secret": params.client_secret = val.string
      else:
        echo "invalid option: $#".format(key)
        util.showHelp()
        break exit
    of cmdArgument:
      if cmd == "":
        cmd = key
      else:
        echo "You need to specify only one command."
    of cmdEnd:
      echo("cannot happen")

proc commandExe() =
  block command:
    var cmd = ""
    for kind, key, val in getOpt():
      cmdOptionParse(kind, key, val, cmd, params)

    if not (cmd == "") and not (cmd == "init"):
      setParams(params)
      if existsFile(params.configFile):
        gapi.refreshTokenIfNeeded(params)
      else:
        case cmd
        of "init", "": discard "skip"
        else:
          echo "config file '$#' doesn't exist".format(params.configFile)
          util.showHelp()
          break command

    case cmd
    of "list":
      gapi.getBlogNames(params)
    of "init":
      if not (params.client_id == "") and not (params.client_secret == ""):
        # Open up default browser, which defined BROWSER environment variable.
        gapi.askAuthorizationWithBrowser(params.client_id)
        let
          input = util.waitInput()
          res   = gapi.tokenRequest(input, params.client_id, params.client_secret)
        gapi.saveResponse(res, params.configFile)
      else:
        echo "You need to set client_id and client_secret."
    of "post":
      gapi.postArticle(params)
    else:
      util.showHelp()

when isMainModule:
  commandExe()
else:
  echo "else"
