#!/usr/bin/env bash
# Install K3s in agent (worker) mode and join it to the server using the shared token.
set -euo pipefail

SERVER_IP="${1:?usage: worker.sh <server-ip> <worker-ip>}"
WORKER_IP="${2:?usage: worker.sh <server-ip> <worker-ip>}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates

# `vagrant up` starts the server first; wait for its token anyway.
for _ in $(seq 1 120); do
  [ -s /vagrant/node-token ] && break
  sleep 2
done
[ -s /vagrant/node-token ] || { echo "node-token not found: is the server up?" >&2; exit 1; }

IFACE="$(ip -o -4 addr show | awk -v ip="${WORKER_IP}" '$4 ~ "^"ip"/" {print $2}')"

curl -sfL https://get.k3s.io | \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="$(cat /vagrant/node-token)" \
  INSTALL_K3S_EXEC="agent --node-ip ${WORKER_IP} --flannel-iface ${IFACE}" sh -
