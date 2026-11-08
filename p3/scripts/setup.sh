#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
END='\033[0m'

if ! k3d cluster list iot >/dev/null 2>&1; then
  printf "${GREEN}Creating k3d cluster 'iot'${END}\n"
  k3d cluster create iot -p "8888:80@loadbalancer" --wait
else
  printf "${GREEN}Reusing existing k3d cluster 'iot'${END}\n"
fi

printf "${GREEN}Creating argocd and dev namespaces${END}\n"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -


printf "${GREEN}Installing Argo CD${END}\n"
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


printf "${GREEN}Waiting for Argo CD pods to be ready${END}\n"
kubectl -n argocd rollout status deployment/argocd-server --timeout=600s
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=600s
kubectl -n argocd rollout status deployment/argocd-applicationset-controller --timeout=600s


printf "${GREEN}Applying Argo CD application${END}\n"
kubectl apply -n argocd -f "./p3/confs/argocd-app.yaml"


printf "${BLUE} Argo CD UI:  kubectl port-forward svc/argocd-server -n argocd 8080:443   ->  https://localhost:8080${END}\n"
printf "${GREEN}  user:      admin${END}\n"
printf "${GREEN}  password:  $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)${END}\n"
printf "${BLUE}App check:   kubectl get pods -n dev ;  curl http://localhost:8888/${END}\n"

