#!/usr/bin/env bash

set -euo pipefail

K3D_VERSION="${K3D_VERSION:-v5.9.0}"

[ "$(id -u)" -ne 0 ] || { echo "run as a normal user (uses sudo)" >&2; exit 1; }
. /etc/os-release
case "${ID}" in debian|ubuntu) ;; *) echo "only Debian/Ubuntu supported" >&2; exit 1 ;; esac

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg

if ! command -v docker >/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "${USER}"

if ! command -v kubectl >/dev/null; then
  KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  sudo curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  sudo chmod +x /usr/local/bin/kubectl
fi

if ! command -v k3d >/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG="${K3D_VERSION}" bash
fi

if ! command -v argocd >/dev/null; then
  sudo curl -fsSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo chmod +x /usr/local/bin/argocd
fi

echo "Done. Log out/in (or run 'newgrp docker') so the docker group applies, then run ./setup.sh"
