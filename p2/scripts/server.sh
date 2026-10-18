#!/usr/bin/env bash
# Install kubectl + K3s (server mode), then deploy the three apps and the Ingress.
set -euo pipefail

SERVER_IP="${1:?usage: server.sh <server-ip>}"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates

KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

IFACE="$(ip -o -4 addr show | awk -v ip="${SERVER_IP}" '$4 ~ "^"ip"/" {print $2}')"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
  --node-ip ${SERVER_IP} \
  --advertise-address ${SERVER_IP} \
  --flannel-iface ${IFACE} \
  --write-kubeconfig-mode 644" sh -

echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' > /etc/profile.d/k3s-kubeconfig.sh
echo "alias k=kubectl" >> /etc/profile.d/k3s-kubeconfig.sh

# Wait for the node and for Traefik (it installs the Ingress controller).
kubectl wait --for=condition=Ready node --all --timeout=300s
until kubectl -n kube-system get deployment traefik >/dev/null 2>&1; do sleep 3; done
kubectl -n kube-system rollout status deployment/traefik --timeout=300s

kubectl apply -f /vagrant/confs/apps.yaml
kubectl apply -f /vagrant/confs/ingress.yaml
for d in app-one app-two app-three; do
  kubectl rollout status deployment/"$d" --timeout=300s
done
