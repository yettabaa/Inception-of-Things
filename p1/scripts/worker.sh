#!/usr/bin/env bash
set -euo pipefail

WORKER_IP="192.168.56.111"
SERVER_IP="192.168.56.110"

IFACE=$(ip -o -4 a | grep ${WORKER_IP} | awk '{print $2}')

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent" sh -s - \
  --node-ip "${WORKER_IP}" \
  --flannel-iface "${IFACE}" \
  --server "https://${SERVER_IP}:6443" \
  --token "$(cat /confs/node-token)"