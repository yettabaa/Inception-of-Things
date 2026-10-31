#!/usr/bin/env bash

set -euo pipefail

CONF_DIR="$(cd "$(dirname "$0")/../confs" && pwd)"

ENV_FILE="$CONF_DIR/.env"
[[ -f "$ENV_FILE" ]] || ENV_FILE="$CONF_DIR/example.env"
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

echo "cleaning up old environment..."
k3d cluster delete bonus 2>/dev/null || true

echo "creating k3d cluster bonus..."
k3d cluster create bonus -p 8888:80@loadbalancer -p 443:443@loadbalancer -p 80:80@loadbalancer -p 222:22@loadbalancer

echo "starting postgres, redis and minio on the host..."
cd "$CONF_DIR"
docker-compose down -v
docker-compose up -d

kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

echo "installing argocd..."
kubectl apply -n argocd --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s

echo "installing gitlab..."
helm repo add gitlab https://charts.gitlab.io/
helm repo update
envsubst < "$CONF_DIR/utils-manif.yaml" | kubectl apply -f -
envsubst < "$CONF_DIR/values.yaml" | helm upgrade --install gitlab gitlab/gitlab \
    --namespace gitlab --timeout 20m --wait -f -

GITLAB_ROOT_PASSWORD="$(kubectl -n gitlab get secret gitlab-gitlab-initial-root-password -o jsonpath='{.data.password}' | base64 -d)"
export GITLAB_ROOT_PASSWORD

echo "pointing argocd at the local gitlab project root/${GITLAB_REPO}..."
envsubst < "$CONF_DIR/argo-app.yaml" | kubectl apply -f -

cat <<MSG

GitLab:   https://gitlab.${GITLAB_IP}.nip.io   user: root   password: ${GITLAB_ROOT_PASSWORD}
          -> create the project "${GITLAB_REPO}" and push the P3 manifests to it (see ../README.md)
Argo CD:  kubectl port-forward svc/argocd-server -n argocd 8080:443 -> https://localhost:8080
          user: admin   password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
App:      kubectl get pods -n dev ; curl http://localhost:8888/
MSG
