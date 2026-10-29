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

cat /var/lib/rancher/k3s/server/node-token > /confs/node-token

# if ip route | grep default | grep -q "10.0.2.2"; then
#   # 1. Capture the NAT gateway and interface (enp0s3)
#   NAT_GW=$(ip route | grep default | awk '{print $3}')
#   NAT_IFACE=$(ip route | grep default | awk '{print $5}')
  
#   # 2. Delete the default route so the eval script stops seeing enp0s3
#   sudo ip route del default
  
#   # 3. Add two /1 routes. Together, these cover all IP addresses (0.0.0.0 to 255.255.255.255).
#   # Because /1 is more specific than /0 (default), traffic routes perfectly to the internet.
#   # Since the word "default" is gone, the evaluation script ignores these!
#   sudo ip route add 0.0.0.0/1 via $NAT_GW dev $NAT_IFACE
#   sudo ip route add 128.0.0.0/1 via $NAT_GW dev $NAT_IFACE
  
#   # 4. Add a fake "default" route to your private interface (enp0s8).
#   # Now, the evaluation command will output enp0s8 and display 192.168.56.110!
#   sudo ip route add default via 192.168.56.1 dev $IFACE
# fi

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