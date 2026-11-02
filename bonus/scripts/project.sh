#!/usr/bin/env bash
# Create the public GitLab project, push the v1 manifests, and point Argo CD at it.
# No /etc/hosts edit needed: gitlab.local is resolved with curl/git options.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
HOST="gitlab.local"
PORT="${PORT:-8888}"
PROJECT="${PROJECT:-reben-ha-iot}"
URL="http://${HOST}:${PORT}"
RESOLVE="${HOST}:${PORT}:127.0.0.1"
MANIFESTS="${HERE}/../../p3/confs/dev-repo/manifests"

# Newer GitLab has no password OAuth grant: mint a 1-day API token for root inside the pod.
TOKEN="$(kubectl -n gitlab exec deploy/gitlab -- gitlab-rails runner \
  "t = User.find_by_username('root').personal_access_tokens.create!(name: 'iot-bonus', scopes: [:api, :write_repository], expires_at: 1.day.from_now); puts t.token" | tail -1)"
[ -n "${TOKEN}" ] || { echo "could not create a GitLab token" >&2; exit 1; }
AUTH="$(printf 'root:%s' "${TOKEN}" | base64 -w0)"

if ! curl -fsS --resolve "${RESOLVE}" -H "PRIVATE-TOKEN: ${TOKEN}" "${URL}/api/v4/projects/root%2F${PROJECT}" >/dev/null 2>&1; then
  curl -fsS --resolve "${RESOLVE}" -H "PRIVATE-TOKEN: ${TOKEN}" "${URL}/api/v4/projects" \
    --data-urlencode "name=${PROJECT}" --data-urlencode "visibility=public" >/dev/null
fi

# Seed v1 only into an empty project: main is protected, and a rerun must not overwrite later pushes.
EMPTY="$(curl -fsS --resolve "${RESOLVE}" -H "PRIVATE-TOKEN: ${TOKEN}" "${URL}/api/v4/projects/root%2F${PROJECT}" \
  | python3 -I -c 'import sys,json; print(json.load(sys.stdin)["empty_repo"])')"
if [ "${EMPTY}" = "True" ]; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "${WORK}"' EXIT
  cp -r "${MANIFESTS}" "${WORK}/manifests"
  sed -i 's/playground:v[0-9]*/playground:v1/' "${WORK}/manifests/deployment.yaml"
  cd "${WORK}"
  git init -q -b main
  git add -A
  git -c user.name=iot -c user.email=iot@local commit -q -m "feat: add playground v1 manifests"
  # Token goes through the credential header, not the URL, so it stays out of logs/.git/config.
  git -c "http.curloptResolve=${RESOLVE}" \
      -c "http.extraHeader=Authorization: Basic ${AUTH}" \
      push -q "${URL}/root/${PROJECT}.git" main
else
  echo "Project already has content; leaving it as is (use set-version.sh to change the version)."
fi

# Argo CD runs inside the cluster, so it uses the in-cluster service, not gitlab.local.
kubectl apply -n argocd -f "${HERE}/../confs/argocd-app.yaml"
echo "Project: ${URL}/root/${PROJECT}  (Argo CD now syncs from GitLab)"
