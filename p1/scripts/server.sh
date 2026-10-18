#!/usr/bin/env bash
# Install kubectl, then K3s in controller (server) mode bound to the private network.
set -euo pipefail

SERVER_IP="${1:?usage: server.sh <server-ip>}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates

# kubectl first: the K3s installer skips its own kubectl symlink if one already exists.
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

# The interface that owns the private IP (name differs per distro: eth1, enp0s8, ...).
IFACE="$(ip -o -4 addr show | awk -v ip="${SERVER_IP}" '$4 ~ "^"ip"/" {print $2}')"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip ${SERVER_IP} \
  --advertise-address ${SERVER_IP} \
  --flannel-iface ${IFACE} \
  --write-kubeconfig-mode 644" sh -

# Hand the join token to the worker through the synced folder (git-ignored).
until [ -s /var/lib/rancher/k3s/server/node-token ]; do sleep 1; done
cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token

echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' > /etc/profile.d/k3s-kubeconfig.sh
echo "alias k=kubectl" >> /etc/profile.d/k3s-kubeconfig.sh
