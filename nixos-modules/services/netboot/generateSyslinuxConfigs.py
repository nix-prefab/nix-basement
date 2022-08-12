import json
import sys
import os

out = os.environ['out']
path = f"{out}"


j = json.loads(sys.argv[1])

os.mkdir(out)
ipxePath = f"{path}/ipxe"
os.mkdir(ipxePath)
confPath = f"{path}/configurations"
os.mkdir(confPath)

for key in j:
  val = j[key]
  os.symlink(f"{val}", f"{confPath}/{key}")
  with open(f'{ipxePath}/{key}.ipxe','w') as o:
    with open(f'{confPath}/{key}/kernel-params','r') as params:
      p = params.read().rstrip()
      o.write(f'''#!ipxe
      set confpath http://${{net0/next-server}}/configurations/{key}
      kernel ${{confpath}}/kernel initrd=initrd init={val}/init nix-basement.nfs-ip=${{net0/next-server}} boot.shell_on_fail {p}
      initrd ${{confpath}}/initrd
      boot''')
