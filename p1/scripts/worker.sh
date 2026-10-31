#!/usr/bin/env bash

WORKER_IP="192.168.56.111"
SERVER_IP="192.168.56.110"

IFACE=$(ip -o -4 addr | grep "${WORKER_IP}" | awk '{print $2}')

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent" sh -s - \
  --node-ip "${WORKER_IP}" \
  --flannel-iface "${IFACE}" \
  --server "https://${SERVER_IP}:6443" \
  --token "$(cat /vagrant/node-token)"
