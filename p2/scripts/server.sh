#!/usr/bin/env bash

SERVER_IP="192.168.56.110"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
  --node-ip "${SERVER_IP}" \
  --write-kubeconfig-mode 644

kubectl apply -f /confs/apps.yaml
kubectl apply -f /confs/ingress.yaml