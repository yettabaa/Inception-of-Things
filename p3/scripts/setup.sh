#!/usr/bin/env bash

set -euo pipefail

CONFS="$(dirname "$0")/../confs"

# host:8888 -> k3d load balancer :80 -> Traefik -> the app
k3d cluster create iot -p "8888:80@loadbalancer" --wait

kubectl create namespace argocd
kubectl create namespace dev

# server-side apply: some Argo CD CRDs exceed the client-side annotation size limit
kubectl apply -n argocd --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s

kubectl apply -n argocd -f "${CONFS}/argocd-app.yaml"

cat <<MSG

Argo CD UI:  kubectl port-forward svc/argocd-server -n argocd 8080:443   ->  https://localhost:8080
  user:      admin
  password:  $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
App check:   kubectl get pods -n dev ;  curl http://localhost:8888/
MSG
