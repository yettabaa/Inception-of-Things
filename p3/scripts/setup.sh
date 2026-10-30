#!/usr/bin/env bash

set -euo pipefail

CLUSTER="${CLUSTER:-iot}"
CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"

if ! k3d cluster list "${CLUSTER}" >/dev/null 2>&1; then
  # host:8888 -> k3d load balancer :80 -> Traefik -> the app (see dev-repo/manifests/ingress.yaml)
  k3d cluster create "${CLUSTER}" -p "8888:80@loadbalancer" --wait
fi

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

# server-side apply: some Argo CD CRDs exceed the client-side annotation size limit
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status deployment/argocd-applicationset-controller --timeout=300s

kubectl apply -n argocd -f "${CONFS}/argocd-app.yaml"

cat <<EOF

Argo CD UI:  kubectl port-forward svc/argocd-server -n argocd 8080:443   ->  https://localhost:8080
  user:      admin
  password:  $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
App check:   kubectl get pods -n dev ;  curl http://localhost:8888/
EOF
