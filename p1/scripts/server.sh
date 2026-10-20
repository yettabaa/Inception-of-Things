#!/usr/bin/env bash

# Dynamically extract the interface holding the private IP (e.g., enp0s8 or eth1)
# -o — output each interface on one line.
# -4 — show IPv4 addresses only.
# addr — show IP addresses assigned to interfaces.
# show — display the information.

SERVER_IP="192.168.56.110"

IFACE="$(ip -o -4 a | grep ${SERVER_IP} | awk '{print $2}')"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
  --node-ip ${SERVER_IP} \
  --advertise-address ${SERVER_IP} \
  --flannel-iface ${IFACE} \
  --write-kubeconfig-mode 644

cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token
