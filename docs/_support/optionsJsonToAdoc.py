#!@python@/bin/python3
import json
from subprocess import Popen, PIPE, STDOUT,run
import sys

inputFile = open(sys.argv[1])
name = sys.argv[2]

data = json.load(inputFile)

def docbookToAdoc(string):
  sprocIn = f'<para>{string}</para>'
  process = run(['@pandoc@/bin/pandoc', '--from=docbook', '--to=asciidoc'], input=sprocIn ,check=True, capture_output=True, text=True);
  return process.stdout
def renderDeclaredBy(obj):
  toReturn = ""
  for x in obj:
    path = x['path']
    url = x['url']
    toReturn = toReturn + f"{url}[<{path}>]\n"
  return toReturn

def dictToNix(obj):
  if obj: # empty dict check
    process = run(['nix-instantiate', '--eval', '-E', f'builtins.fromJSON \'\'{json.dumps(obj)}\'\''], check=True, capture_output=True, text=True);
    return process.stdout
  else:
    return '{}'

def renderObject(obj, indent = 0):
  tr = ''
  ids = ' ' * indent
  if '_type' in obj:
    return obj['text']
  tr = ids + '{'
  for k,v in obj.items():
    if type(v) is dict:
      if '_type' in v:
        if v['_type'] == "literalExpression" or v['_type'] == 'literalExample':
          tr += ids + f"{k} = {v['text']};\n"
      else:
          tr += ids + f"{k} = {renderObject(v,indent+2)};\n"
    elif type(v) is bool:
      tr += ids + f"{k} = {'true' if v == True else 'false'};\n"
    else:
      tr += ids + f"{k} = {v};\n"

  tr += ids + '}'
  return tr

def renderLiteralStuff(obj):
  if type(obj) is dict:
    return renderObject(obj)
  else:
    return obj


print(f"""= {name}
:sectlinks:

== Option List
""")
for optionName, optionData in data.items():
  #nestLevel = len(optionName.split('.'))
  nestLevel = 2
  print(f"""[,{optionName}]
{"=" * (nestLevel +1)} {optionName}
""")
  if 'description' in optionData:
    print(f"""Description:: {docbookToAdoc(optionData['description']) or ""}""")
  print("****")
  if 'type' in optionData:
    print(f"""Type:: {optionData['type']}""")
  if 'default' in optionData:
    print(f"""Default:: `{renderLiteralStuff(optionData['default'])}`""")
  if 'example' in optionData:
    print(f"""Example:: `{renderLiteralStuff(optionData['example'])}`""")
  if 'relatedPackages' in optionData:
    print(f"""Related Packages:: {optionData['relatedPackages']}""")
  if 'declarations' in optionData:
    print(f"""Declared by:: {renderDeclaredBy(optionData['declarations'])}""")
  if 'definitions' in optionData:
    print(f"""Defined by:: {optionData['definitions']}""")
  print("****")

  print()

inputFile.close()
#outputFile.close()
