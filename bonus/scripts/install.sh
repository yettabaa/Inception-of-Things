#!/usr/bin/sh

echo "installing requirements..."
apt-get update -y && apt-get install -y docker.io curl

echo "installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"                         
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

echo "installing k3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "installing helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
bash get_helm.sh

echo "cleaning..."
rm -rf get_helm.sh kubectl
