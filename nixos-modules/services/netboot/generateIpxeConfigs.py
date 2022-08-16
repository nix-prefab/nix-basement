import json
import sys
import os

out = os.environ['out']
path = f"{out}"


j = json.loads(sys.argv[1])
ipxe = sys.argv[2]

ipxePath = f"{path}/ipxe"
os.mkdir(ipxePath)
confPath = f"{path}/configurations"
os.mkdir(confPath)

for fl in os.listdir(ipxe):
  os.symlink(f"{ipxe}/{fl}", f"{out}/{fl}")

for key in j:
  val = j[key]
  os.symlink(f"{val}", f"{confPath}/{key}")
  with open(f'{ipxePath}/{key}.ipxe','w') as o:
    with open(f'{confPath}/{key}/kernel-params','r') as params:
      p = params.read().rstrip()
      o.write(f'''#!ipxe
      set confpath http://${{net0/next-server}}/configurations/{key}
      kernel ${{confpath}}/kernel initrd=initrd init={val}/init boot.shell_on_fail {p}
      initrd ${{confpath}}/initrd
      boot''')
