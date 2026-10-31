#!/usr/bin/env bash

SERVER_IP="192.168.56.110"

IFACE=$(ip -o -4 addr | grep "${SERVER_IP}" | awk '{print $2}')

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
  --node-ip "${SERVER_IP}" \
  --flannel-iface "${IFACE}" \
  --write-kubeconfig-mode 644

# /vagrant is the project folder, synced into the VM by default.
kubectl apply -f /vagrant/confs/
