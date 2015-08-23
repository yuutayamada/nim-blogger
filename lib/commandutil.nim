# utility functions


proc waitInput*(): string =
  echo """
  Check your browser and push accept button, and then
  paste result here:
  """
  result = readLine(stdin)
  echo "input result was: '" & result & "'"

  echo """
  You can disable this permission anytime:
  https://security.google.com/settings/security/permissions
  """

proc showHelp*() =
  echo """
  nimblogger -- Command Line Google Blogger Interface

  nimblogger [COMMAND] [OPTION]...

  Options:
  -h, or --help:
    Help for this message

  Commands:
    init: get authorization from Google. You need to invoke this command at first time.
    list: list your blog names
    post: post a blog article
      exmaple -- nimblogger post -t title -n blogname -f foo.html
    [wip] update: update post
  """
