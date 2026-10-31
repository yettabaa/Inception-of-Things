#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR="$(cd -- "$SCRIPT_DIR/../confs" && pwd)"
ENV_FILE="${ENV_FILE:-$CONF_DIR/.env}"

if [[ ! -f "$ENV_FILE" ]]; then
    ENV_FILE="$CONF_DIR/example.env"
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

BS_ARGOCD_CONFS="$CONF_DIR/argo-app.yaml"
BS_NS_ARGOCD="argocd"
BS_NS_DEV="dev"
BS_NS_GITLAB="gitlab"
BS_CLUSTER="bonus"
ARGOCD_YAML="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

echo "cleaning up old evironments..."
k3d cluster delete $BS_CLUSTER 2>/dev/null

echo "creating k3s cluster $BS_CLUSTER..."
k3d cluster create $BS_CLUSTER -p 8888:80@loadbalancer -p 443:443@loadbalancer -p 80:80@loadbalancer -p 222:22@loadbalancer

cd "$CONF_DIR"
docker-compose down -v
docker-compose up -d

echo "creating namespaces $BS_NS_ARGOCD, $BS_NS_DEV, $BS_NS_GITLAB..."
kubectl create namespace "$BS_NS_ARGOCD"
kubectl create namespace "$BS_NS_DEV"
kubectl create namespace "$BS_NS_GITLAB"

echo "installing argocd..."
kubectl apply -n "$BS_NS_ARGOCD" --server-side -f "$ARGOCD_YAML"

echo "waiting for argocd pods to boot..."
sleep 8
kubectl wait --for=condition=Ready pods --all -n "$BS_NS_ARGOCD" --timeout=300s

echo "applying argocd configurations: $BS_ARGOCD_CONFS..."
kubectl apply -f $BS_ARGOCD_CONFS

echo "extracting argocd password:"
kubectl -n "$BS_NS_ARGOCD" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "installing gitlab..."
helm repo add gitlab https://charts.gitlab.io/
helm repo update

envsubst < "$CONF_DIR/utils-manif.yaml" | kubectl apply -f -

envsubst < "$CONF_DIR/values.yaml" | helm upgrade --install gitlab gitlab/gitlab \
    --namespace "$BS_NS_GITLAB" --timeout 20m --wait -f -

echo "extracting gitlab root password:"
kubectl -n "$BS_NS_GITLAB" get secret gitlab-gitlab-initial-root-password \
    -o jsonpath="{.data.password}" | base64 -d
echo ""

# echo "skipping ssl srtf checks for special repo..."
# argocd repo add https://gitlab.10.32.66.207.nip.io/root/REPO_NAME.git --insecure-skip-server-verification
