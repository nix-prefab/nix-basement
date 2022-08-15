#!/usr/bin/env zsh

export NONINTERACTIVE=1

echo "[+] Installing Brew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo "[+] Installing nix"
sh <(curl -L https://nixos.org/nix/install)

echo "[+] Refreshing Path"
. /etc/zshrc

echo "[+] Building Nix-Darwin Configuration"
ND_CONF=$(nix build --no-link "$1")


echo "[+] Removing /etc/nix/nix.conf"
sudo rm /etc/nix/nix.conf
echo "[+] Patching /etc/synthetic.conf"
printf 'run\tprivate/var/run\n' | sudo tee -a /etc/synthetic.conf
echo "[+] APFS Refresh"
/System/Library/Filesystems/apfs.fs/Contents/Resouces/apfs.util -t
echo "[+] darwin-rebuild"
$ND_CONF/sw/bin/darwin-rebuild switch --flake "$1"

echo "[+] patching /etc/bashrc and /etc/zshrc"

echo 'if test -e /etc/static/bashrc; then . /etc/static/bashrc; fi' | sudo tee -a /etc/bashrc
echo 'if test -e /etc/static/zshrc; then . /etc/static/zshrc; fi' | sudo tee -a /etc/zshrc

echo "[+] done"
