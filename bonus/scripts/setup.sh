#!/usr/bin/env bash
# Deploy the latest GitLab CE into namespace "gitlab" on the P3 k3d cluster.
# Needs ~4-6 GB of free RAM and 5-15 minutes (large image + first boot).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLUSTER="${CLUSTER:-iot}"

# Reuse the P3 cluster (Argo CD, namespace dev, port 8888); build it if missing.
k3d cluster list "${CLUSTER}" >/dev/null 2>&1 || "${HERE}/../../p3/scripts/setup.sh"

kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -

# Random root password, created once and kept in the cluster (never in the repo).
if ! kubectl -n gitlab get secret gitlab-root-password >/dev/null 2>&1; then
  kubectl -n gitlab create secret generic gitlab-root-password \
    --from-literal=password="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
fi

kubectl apply -f "${HERE}/../confs/gitlab.yaml"
kubectl -n gitlab rollout status deployment/gitlab --timeout=1500s

echo
echo "GitLab: http://gitlab.local:8888   (add '127.0.0.1 gitlab.local' to /etc/hosts for a browser)"
echo "  user: root"
echo "  password: kubectl -n gitlab get secret gitlab-root-password -o jsonpath='{.data.password}' | base64 -d"
echo "Next: ${HERE}/project.sh"
