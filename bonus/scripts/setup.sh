#!/usr/bin/env bash
# Bonus setup: k3d cluster + ArgoCD + GitLab (helm) + app via local GitLab

set -euo pipefail

CLUSTER="${CLUSTER:-iot-bonus}"
CONFS="$(cd "$(dirname "$0")/../confs" && pwd)"
GITLAB_NS="gitlab"
ARGOCD_NS="argocd"
DEV_NS="dev"

# ── 1. Cluster ────────────────────────────────────────────────────────────────
if ! k3d cluster list "${CLUSTER}" >/dev/null 2>&1; then
  k3d cluster create "${CLUSTER}" -p "8888:80@loadbalancer" --wait
fi

# ── 2. Namespaces ─────────────────────────────────────────────────────────────
for ns in "${ARGOCD_NS}" "${DEV_NS}" "${GITLAB_NS}"; do
  kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f -
done

# ── 3. ArgoCD ─────────────────────────────────────────────────────────────────
kubectl apply -n "${ARGOCD_NS}" --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n "${ARGOCD_NS}" rollout status deployment/argocd-server                       --timeout=300s
kubectl -n "${ARGOCD_NS}" rollout status deployment/argocd-repo-server                  --timeout=300s
kubectl -n "${ARGOCD_NS}" rollout status deployment/argocd-applicationset-controller    --timeout=300s

# ── 4. GitLab (helm) ──────────────────────────────────────────────────────────
helm repo add gitlab https://charts.gitlab.io/ 2>/dev/null || true
helm repo update gitlab

helm upgrade --install gitlab gitlab/gitlab \
  --namespace "${GITLAB_NS}" \
  --version 7.11.10 \
  --timeout 1200s \
  --wait=false \
  -f "${CONFS}/gitlab-values.yaml"

# ── 5. Retrieve GitLab root password ──────────────────────────────────────────
GITLAB_PASSWORD="$(kubectl -n "${GITLAB_NS}" get secret gitlab-gitlab-initial-root-password \
  -o jsonpath='{.data.password}' | base64 -d)"

# ── 6. Bootstrap GitLab repo via the API ─────────────────────────────────────
# Port-forward GitLab webservice so we can reach the API from this host
kubectl -n "${GITLAB_NS}" port-forward svc/gitlab-webservice-default 8929:8080 &
PF_PID=$!
trap 'kill ${PF_PID} 2>/dev/null || true' EXIT
sleep 10   # wait for port-forward to be ready

GITLAB_URL="http://localhost:8929"

# Get an OAuth token for root
OAUTH_TOKEN="$(curl -fsSL \
  --request POST "${GITLAB_URL}/oauth/token" \
  --data "grant_type=password&username=root&password=${GITLAB_PASSWORD}" \
  | grep -oP '(?<="access_token":")[^"]+')"

# Create a personal access token with API + write_repository scopes
PAT="$(curl -fsSL \
  --request POST "${GITLAB_URL}/api/v4/users/1/personal_access_tokens" \
  --header "Authorization: Bearer ${OAUTH_TOKEN}" \
  --data "name=argocd&scopes[]=api&scopes[]=write_repository" \
  | grep -oP '(?<="token":")[^"]+')"

# Create the 'playground' project (public, so ArgoCD can pull without auth)
curl -fsSL \
  --request POST "${GITLAB_URL}/api/v4/projects" \
  --header "PRIVATE-TOKEN: ${PAT}" \
  --data "name=playground&visibility=public&initialize_with_readme=false" \
  > /dev/null 2>&1 || true

# Push app manifests into the local repo
TMP_DIR="$(mktemp -d)"
git clone "http://oauth2:${PAT}@localhost:8929/root/playground.git" "${TMP_DIR}" 2>/dev/null \
  || git -C "${TMP_DIR}" init
cp "${CONFS}/deployment.yaml" "${TMP_DIR}/deployment.yaml"
git -C "${TMP_DIR}" config user.email "root@gitlab.local"
git -C "${TMP_DIR}" config user.name  "root"
git -C "${TMP_DIR}" add .
git -C "${TMP_DIR}" diff --cached --quiet \
  || git -C "${TMP_DIR}" commit -m "initial: add playground deployment"
git -C "${TMP_DIR}" remote set-url origin \
  "http://oauth2:${PAT}@localhost:8929/root/playground.git" 2>/dev/null || true
git -C "${TMP_DIR}" push -u origin HEAD:main
rm -rf "${TMP_DIR}"

kill "${PF_PID}" 2>/dev/null || true
trap - EXIT

# ── 7. ArgoCD Application (points to local GitLab inside the cluster) ─────────
kubectl apply -n "${ARGOCD_NS}" -f "${CONFS}/argocd-app.yaml"

# ── 8. Summary ────────────────────────────────────────────────────────────────
ARGOCD_PASSWORD="$(kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)"

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Argo CD UI  : kubectl port-forward svc/argocd-server -n argocd 8080:443
               → https://localhost:8080
               user: admin  /  password: ${ARGOCD_PASSWORD}

 GitLab UI   : kubectl port-forward svc/gitlab-webservice-default -n gitlab 8929:8080
               → http://localhost:8929
               user: root   /  password: ${GITLAB_PASSWORD}

 App         : kubectl get pods -n dev
               curl http://localhost:8888/

 To update the app version:
   edit bonus/confs/deployment.yaml (change v1 → v2), commit and push
   to your local GitLab → ArgoCD will sync automatically.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
