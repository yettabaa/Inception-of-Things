#!/usr/bin/env bash

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
END='\033[0m'

if [ "$EUID" -eq 0 ]; then
    echo "Please run as a normal user (uses sudo)." >&2
    exit 1
fi

sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg

# Install Docker

if ! command -v docker >/dev/null; then
  printf "${BLUE}Installing Docker...${END}\n"

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
else
  printf "${GREEN}Docker is already installed.${END}\n"
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "${USER}"

# Install kubectl

if ! command -v kubectl >/dev/null; then
  printf "${BLUE}Installing kubectl...${END}\n"

  KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  sudo curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  sudo chmod +x /usr/local/bin/kubectl
else
  printf "${GREEN}kubectl is already installed.${END}\n"
fi

# Install k3d

if ! command -v k3d >/dev/null; then
  printf "${BLUE}Installing k3d...${END}\n"
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG="v5.9.0" bash
else
  printf "${GREEN}k3d is already installed.${END}\n"
fi

# Install ArgoCD

if ! command -v argocd >/dev/null; then
  printf "${BLUE}Installing ArgoCD...${END}\n"
  sudo curl -fsSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo chmod +x /usr/local/bin/argocd
else
  printf "${GREEN}ArgoCD is already installed.${END}\n"
fi
