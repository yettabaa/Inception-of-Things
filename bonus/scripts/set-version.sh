#!/usr/bin/env bash
# Defense demo: switch the app version in the local GitLab repo, e.g.  ./set-version.sh v2
# Argo CD then syncs it into namespace "dev" (it polls every ~3 min; this script forces a refresh).
set -euo pipefail

VERSION="${1:?usage: set-version.sh <v1|v2>}"
[[ "${VERSION}" =~ ^v[0-9]+$ ]] || { echo "version must look like v1, v2" >&2; exit 1; }
HOST="gitlab.local"
PORT="${PORT:-8888}"
PROJECT="${PROJECT:-reben-ha-iot}"
RESOLVE="${HOST}:${PORT}:127.0.0.1"

TOKEN="$(kubectl -n gitlab exec deploy/gitlab -- gitlab-rails runner \
  "puts User.find_by_username('root').personal_access_tokens.create!(name: 'iot-demo', scopes: [:write_repository], expires_at: 1.day.from_now).token" | tail -1)"
AUTH="$(printf 'root:%s' "${TOKEN}" | base64 -w0)"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
git_gl() { git -c "http.curloptResolve=${RESOLVE}" -c "http.extraHeader=Authorization: Basic ${AUTH}" "$@"; }

git_gl clone -q "http://${HOST}:${PORT}/root/${PROJECT}.git" "${WORK}/repo"
cd "${WORK}/repo"
sed -i "s/playground:v[0-9]*/playground:${VERSION}/" manifests/deployment.yaml
if git diff --quiet; then
  echo "already ${VERSION}"
else
  git -c user.name=iot -c user.email=iot@local commit -qam "feat: bump playground to ${VERSION}"
  git_gl push -q origin main
fi

kubectl -n argocd annotate app playground argocd.argoproj.io/refresh=hard --overwrite >/dev/null
for _ in $(seq 1 60); do
  out="$(curl -s -m 3 http://localhost:8888/ || true)"
  case "${out}" in *"\"${VERSION}\""*) echo "${out}"; exit 0 ;; esac
  sleep 5
done
echo "timeout: app did not reach ${VERSION}" >&2
exit 1
