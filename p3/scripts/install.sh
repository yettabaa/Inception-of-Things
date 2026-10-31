#!/usr/bin/env bash

set -euo pipefail

sudo apt-get update -y
sudo apt-get install -y docker.io curl
sudo systemctl enable --now docker
sudo usermod -aG docker "${USER}"

ARCH="$(dpkg --print-architecture)"   # amd64 or arm64
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
sudo curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
sudo chmod +x /usr/local/bin/kubectl

curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

sudo curl -fsSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${ARCH}
sudo chmod +x /usr/local/bin/argocd

echo "Done. Log out/in (or run 'newgrp docker') so the docker group applies, then run ./setup.sh"
