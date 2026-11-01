#!/usr/bin/env bash

SERVER_IP="192.168.56.110"

IFACE=$(ip -o -4 a | grep ${SERVER_IP} | awk '{print $2}')

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
  --node-ip "${SERVER_IP}" \
  --flannel-iface "${IFACE}" \
  --advertise-address "${SERVER_IP}" \
  --write-kubeconfig-mode 644

cat /var/lib/rancher/k3s/server/node-token > /confs/node-token
