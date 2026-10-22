#!/usr/bin/env bash

SERVER_IP="192.168.56.110"

# Dynamically extract the interface holding the private IP (e.g., enp0s8 or eth1)
# -o — output each interface on one line.
# -4 — show IPv4 addresses only.
# addr — show IP addresses assigned to interfaces.
# show — display the information.

IFACE=$(ip -o -4 a | grep ${SERVER_IP} | awk '{print $2}')

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
  --node-ip ${SERVER_IP} \
  --flannel-iface ${IFACE} \
  --advertise-address ${SERVER_IP} \
  --write-kubeconfig-mode 644

cat /var/lib/rancher/k3s/server/node-token > /vagrant/node-token


# BOX = "bento/debian-13"
# vagrant@yettabaaS:~$ free -h
#                total        used        free      shared  buff/cache   available
# Mem:           967Mi       782Mi        84Mi       540Ki       235Mi       185Mi
# Swap:          3.0Gi       202Mi       2.8Gi

# BOX = "bento/ubuntu-22.04"
# vagrant@yettabaaS:~$ free -h
#                total        used        free      shared  buff/cache   available
# Mem:           957Mi       681Mi        63Mi       0.0Ki       212Mi       133Mi
# Swap:          2.9Gi       452Mi       2.5Gi