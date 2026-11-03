#!/usr/bin/env bash

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
END='\033[0m'
GITLAB_VERSION="19.5.3-ce.0"

printf "${GREEN} Reuse the P3 cluster build it if missing. ${END}\n"
k3d cluster list iot >/dev/null 2>&1 || ./p3/scripts/setup.sh

printf "${GREEN}Creating namespace gitlab${END}\n"
kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -


printf "${GREEN}Pulling GitLab image and importing into k3d cluster...${END}\n"
if ! docker exec k3d-iot-server-0 crictl images | grep -q "gitlab/gitlab-ce.*${GITLAB_VERSION}"; then
  docker pull gitlab/gitlab-ce:${GITLAB_VERSION}
  k3d image import gitlab/gitlab-ce:${GITLAB_VERSION} -c iot
else
  printf "${GREEN}GitLab image is already imported into k3d cluster.${END}\n"
fi


printf "${GREEN}Generate and store GitLab's root password if not already set. ${END}\n"
if ! kubectl -n gitlab get secret gitlab-root-password >/dev/null 2>&1; then
  kubectl -n gitlab create secret generic gitlab-root-password \
    --from-literal=password="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
fi

printf "${GREEN}Deploying GitLab...${END}\n"
kubectl apply -f ./bonus/confs/gitlab.yaml
kubectl -n gitlab rollout status deployment/gitlab-deployment --timeout=6000s

printf "${BLUE}GitLab: http://gitlab.local:8888   (add '127.0.0.1 gitlab.local' to /etc/hosts for a browser)${END}\n"
printf "${GREEN}  user: root${END}\n"
printf "${GREEN}  password: $(kubectl -n gitlab get secret gitlab-root-password -o jsonpath='{.data.password}' | base64 -d)${END}\n"
printf "${BLUE}Next: ./bonus/scripts/add-app.sh${END}\n"
