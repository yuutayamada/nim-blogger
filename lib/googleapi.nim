import
  strutils, json, httpclient, browsers, os, logging, strutils,
  strtabs, marshal, cgi, unicode

type # those are for marshal
  Res = object
    headers: Headers
    body: Body

  Headers = object
    date: string
    vary: string
    accept_ranges: string
    x_xss_protection: string
    x_frame_options: string
    alt_svc: string
    pragma: string
    content_type: string
    expires: string
    server: string
    alternate_protocol: string
    cache_control: string
    x_content_type_options: string
    transfer_encoding: string

  Body = object
    access_token: string
    token_type: string
    expires_in: int
    refresh_token: string

type
  Params* = ref object
    client_id*: string
    client_secret*: string
    access_token*: string
    token_type*: string
    authHeader*: string
    refresh_token*: string
    configFile*: string
    blogname*: string
    sourceFile*: string
    title*: string
    labels*: string

const redirect_uri = "redirect_uri=urn:ietf:wg:oauth:2.0:oob"
const scope = "https://www.googleapis.com/auth/blogger" ##\
              ## https://developers.google.com/blogger/docs/3.0/using#auth

proc refreshToken*(p: Params) =
  let
    url = "https://www.googleapis.com/oauth2/v3/token?"
    grant_type = "grant_type=refresh_token"
    ref_token = "refresh_token=" & p.refresh_token
    params = join([grant_type, ref_token, p.client_id, p.client_secret], "&")

  let res = post(url & params)
  if res.status == "200 OK":
    let
      body = parseJson(res.body)
      new_access_token = body["access_token"].str
      config: JsonNode = parseFile(p.configFile)

    delete(config["body"], "access_token")
    add(config["body"], "access_token", newJString(new_access_token))
    writeFile(p.configFile, pretty(config))
  else:
    echo "Refresh token failed"
    echo res

proc refreshTokenIfNeeded*(p: Params) =
  const url = "https://www.googleapis.com/blogger/v3/users/self/blogs"
  let res = get(url, p.authHeader & "\c\L") # try access
  case res.status:
    of "200 OK":
      discard "do nothing"
    of "401 Unauthorized":
      echo "refresh token"
      refreshToken(p)
    else:
      echo "Update error" # todo make error

proc askAuthorizationWithBrowser*(client_id: string) =
  ## Get permission from Google for Blogger
  ## To delete permission:
  ##   https://security.google.com/settings/security/permissions?pli=1
  const
    endpoint      = "https://accounts.google.com/o/oauth2/auth?"
    response_type = "response_type=code"
  let params = [scope, redirect_uri, response_type, client_id]
  openDefaultBrowser(endpoint & join(params, "&"))

proc saveResponse*(res: Response, configFile: string) =

  var
    headers: Headers
    body: Body

  if res.status == "200 OK" and fileExists(configFile):
    for k, v in res.headers.pairs:
      if k is string and v is string:
        case k:
        of "Date": headers.date = v
        of "Vary": headers.vary = v
        of "Accept-Ranges": headers.accept_ranges = v
        of "X-XSS-Protection": headers.x_xss_protection = v
        of "X-Frame-Options": headers.x_frame_options = v
        of "Alt-Svc": headers.alt_svc = v
        of "Pragma": headers.pragma = v
        of "Content-Type": headers.content_type = v
        of "Expires": headers.expires = v
        of "Server": headers.server = v
        of "Alternate-Protocol": headers.alternate_protocol = v
        of "Cache-Control": headers.cache_control = v
        of "X-Content-Type-Options": headers.x_content_type_options = v
        of "Transfer-Encoding": headers.transfer_encoding = v
        else: discard

    let b = parseJson(res.body)
    if b is JsonNode:
      body.access_token = b["access_token"].str
      body.token_type = b["token_type"].str
      body.expires_in = b["expires_in"].num.int
      body.refresh_token = b["refresh_token"].str
    # save token request
    writeFile(configFile,
              $$(Res(headers: headers, body: body)))
    echo "successfully saved at ", configFile
  else:
    logging.error("http status code is not ok: $1" % res.status)

proc tokenRequest*(code, client_id, client_secret: string): Response =
  ## Handling the response and making a token request
  ## The authorization CODE returned from the initial request.
  const
    endpoint = "https://www.googleapis.com/oauth2/v3/token?"
    grant_type = "grant_type=authorization_code"

  let
    params = join(["code=" & code, client_id, client_secret, redirect_uri, grant_type], "&")
  # return response
  post(endpoint & params)

proc getBlogNames*(p: Params) =
  const url = "https://www.googleapis.com/blogger/v3/users/self/blogs"
  let res = get(url, p.authHeader & "\c\L")
  if res.status == "200 OK":
    let content = parseJson(res.body)
    # For debug purpose
    # echo content
    for blog in content["items"]:
      echo "blog name: ", blog["name"], "id: ", blog["id"]
  elif res.status == "401 Unauthorized":
    echo "refresh token"
    refreshToken(p)
  else:
    echo "error"

# https://developers.google.com/apis-explorer/#p/blogger/v3/
proc getBlogIDFromName*(blogname, authHeader: string): string =
  result = "" # ID

  const url = "https://www.googleapis.com/blogger/v3/users/self/blogs"
  let res = httpclient.get(url, authHeader & "\c\L")

  if res.status == "200 OK":
    let content = parseJson(res.body)
    for blog in content["items"]:
      if blogname == blog["name"].str:
        result = blog["id"].str
        break

proc escapeDoubleQuote(dest: var string, r: Rune) {.inline.} =
  case r
  of '\"'.int.Rune: add(dest, "\\\"")
  of '\\'.int.Rune: add(dest, "\\\\")
  else: add(dest, $(r))

proc escapeForGoogleBlogger(s: string): string =
  ## escape double quotes of blog content
  result = newStringOfCap(s.len + s.len shr 2)
  for r in runes(s): escapeDoubleQuote(result, r)

# https://developers.google.com/blogger/docs/3.0/using
# adding a post exmaple
proc postArticle*(p: Params) =
  var
    content = escapeForGoogleBlogger(readFile(p.sourceFile).string)
    contentEscaped = ""
    labelsElem = ""

  if p.labels != "":
    labelsElem = """,
    "labels": [
      "$#"
    ]
    """.format(p.labels)
  for sentence in strutils.split(content, NewLines):
    contentEscaped &= sentence & "\\n"
  # Posting example:
  #   https://developers.google.com/blogger/docs/3.0/reference/posts#resource
  let
    blogid = getBlogIDFromName(p.blogname, p.authHeader)
    params = "posts?fetchBody=true&fetchImages=false&isDraft=true"
    url = "https://www.googleapis.com/blogger/v3/blogs/$#/$#".format(blogid, params)
    headers = p.authHeader & "\c\L" & "Content-Type: application/json\c\L"
    json = """
    {
      "kind": "blogger#post",
      "blog": {
        "id": "$#"
      },
      "title": "$#",
      "content": "$#"
      $#
    }
    """.format(blogid, p.title, contentEscaped, labelsElem)

  let res = httpclient.post(url, headers, json)
  if res.status == "200 OK":
    echo "Succeed"
    os.removeFile(p.sourceFile)
  else:
    echo "Failed", res
