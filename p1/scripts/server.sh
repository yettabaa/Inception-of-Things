#!/usr/bin/env bash

SERVER_IP="192.168.56.110"

# Interface that holds the private IP (enp0s8), so K3s does not pick the NAT one.
IFACE=$(ip -o -4 addr | grep "${SERVER_IP}" | awk '{print $2}')

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
  --node-ip "${SERVER_IP}" \
  --flannel-iface "${IFACE}" \
  --advertise-address "${SERVER_IP}" \
  --write-kubeconfig-mode 644

# /vagrant is the project folder, synced into every VM by default.
cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token
