import json
import sys
import os

out = os.environ['out']
path = f"{out}"


j = json.loads(sys.argv[1])

confPath = f"{path}/configurations"

for key in j:
  val = j[key]
  toplevel = val["toplevel"]
  fw = val["fw"]
  keypath = f"{out}/{key}"
  os.mkdir(keypath)
  os.symlink(f"{toplevel}", f"{confPath}/{key}")
  for fl in os.listdir(fw):
    os.symlink(f"{fw}/{fl}", f"{keypath}/{fl}")
  os.unlink(f"{keypath}/kernel.img")
  os.symlink(f"{toplevel}/initrd", f"{keypath}/initrd")
  os.symlink(f"{toplevel}/kernel", f"{keypath}/kernel.img")
  with open(f'{keypath}/config.txt','w') as o:
    o.write(
f'''avoid_warnings=1
arm_64bit=1
kernel=kernel.img
initramfs initrd followkernel
boot''')
  with open(f'{confPath}/{key}/kernel-params','r') as params:
      p = params.read().rstrip()
      with open(f'{keypath}/cmdline.txt','w') as o:
        o.write(f"{p} initrd=initrd init={toplevel}/init boot.shell_on_fail")
