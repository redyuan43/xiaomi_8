#!/bin/sh
set -eu

[ "$(id -u)" -eq 0 ] || {
    echo "run as root" >&2
    exit 1
}

key_url=https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg
list_url=https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

curl -fsSL "$key_url" -o "$tmp/tailscale-archive-keyring.gpg"
curl -fsSL "$list_url" -o "$tmp/tailscale.list"
install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d
install -m 0644 "$tmp/tailscale-archive-keyring.gpg" \
    /usr/share/keyrings/tailscale-archive-keyring.gpg
install -m 0644 "$tmp/tailscale.list" /etc/apt/sources.list.d/tailscale.list

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y tailscale
for family in iptables ip6tables; do
    legacy="/usr/sbin/$family-legacy"
    if [ -x "$legacy" ]; then
        update-alternatives --set "$family" "$legacy"
    fi
done
systemctl enable --now tailscaled.service
tailscale version
