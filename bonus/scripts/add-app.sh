#!/usr/bin/env bash

set -euo pipefail

GITLAB="http://gitlab.local:8888"
REPO="yettabaa-iot-app"
TMP_DIR="/tmp/${REPO}.git"
GITHUB="https://github.com/yettabaa/yettabaa-iot-app.git"
GREEN='\033[0;32m'
END='\033[0m'

printf "${GREEN}Generating GitLab access token...${END}\n"
TOKEN=$(kubectl -n gitlab exec deployment/gitlab-deployment -- \
  gitlab-rails runner '
    user = User.find_by_username("root")
    token = user.personal_access_tokens.create!(
      name: "iot-import",
      scopes: [:api],
      expires_at: 1.days.from_now
    )
    puts token.token
  ')

  
printf "${GREEN}Creating public GitLab project...${END}\n"
if ! curl -fsS -X GET -H "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB}/api/v4/projects/root%2F${REPO}" >/dev/null; then
  curl -fsS -X POST -H "PRIVATE-TOKEN: ${TOKEN}" "${GITLAB}/api/v4/projects" \
    --data-urlencode "name=${REPO}" --data-urlencode "visibility=public" >/dev/null
fi

printf "${GREEN}Cloning GitHub repository...${END}\n"
rm -rf "${TMP_DIR}"
git clone "${GITHUB}" "${TMP_DIR}"


printf "${GREEN}Pushing to GitLab...${END}\n"
git -C "${TMP_DIR}" push "http://root:${TOKEN}@gitlab.local:8888/root/${REPO}.git"


printf "${GREEN}Creating Argo CD application...${END}\n"
kubectl apply -n argocd -f "./bonus/confs/argocd-app.yaml"
kubectl -n argocd rollout status deployment/argocd-applicationset-controller --timeout=6000s

