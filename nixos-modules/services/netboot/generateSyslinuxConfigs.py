import json
import sys
import os

out = os.environ['out']
cfgPaths = [ f"{out}/efi64", f"{out}" ]


j = json.loads(sys.argv[1])

os.mkdir(f"{out}/efi64")
for path in cfgPaths:
  cfgPath = f"{path}/pxelinux.cfg"
  os.mkdir(cfgPath)
  kernelPath = f"{path}/configurations"
  os.mkdir(kernelPath)
  for key in j:
    val = j[key]
    os.symlink(f"{val}", f"{kernelPath}/{key}")
    with open(f'{cfgPath}/{key}','w') as o:
      with open(f'{kernelPath}/{key}/kernel-params','r') as params:
        p = params.read().rstrip()
        o.write(f'''DEFAULT nixos
        LABEL nixos
        LINUX configurations/{key}/kernel
        APPEND initrd=configurations/{key}/initrd init={val}/init {p}''')
