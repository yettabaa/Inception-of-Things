#!/usr/bin/env bash

WORKER_IP="192.168.56.111"
SERVER_IP="192.168.56.110"

IFACE="$(ip -o -4 a | grep ${WORKER_IP} | awk '{print $2}')"

TOKEN=$(cat /vagrant/node-token)

curl -sfL https://get.k3s.io | K3S_URL=https://192.168.56.110:6443 K3S_TOKEN="${TOKEN}" sh -s - --flannel-iface=${IFACE} --node-ip=${WORKER_IP} 