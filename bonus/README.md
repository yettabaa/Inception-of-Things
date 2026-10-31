# Bonus: local GitLab as the Argo CD source

Same lab as P3, but the manifests live in a GitLab running in the cluster
(namespace `gitlab`, installed with Helm) instead of GitHub.

## Layout

- `scripts/install.sh`: Docker, kubectl, k3d, Helm.
- `scripts/setup.sh`: k3d cluster, Postgres/Redis/MinIO on the host (`confs/docker-compose.yaml`),
  Argo CD, GitLab (`confs/values.yaml`), then the Argo CD Application (`confs/argo-app.yaml`).
- `confs/example.env`: settings; copy it to `confs/.env` (git-ignored) and set `GITLAB_IP`
  to the IP of this machine. `GITLAB_REPO` is the GitLab project Argo CD will watch.

## Run

```sh
sudo ./scripts/install.sh      # once, then log out/in for the docker group
./scripts/setup.sh             # ~15 min, prints the GitLab and Argo CD passwords
```

Then in GitLab (`https://gitlab.<GITLAB_IP>.nip.io`, user `root`):

1. Create a project named like `GITLAB_REPO` (default `iot-app`) under `root`.
2. Push the P3 manifests (deployment, service, ingress for `wil42/playground`) to it.
3. Argo CD syncs it into the `dev` namespace; `curl http://localhost:8888/` returns `v1`.
4. Change the image tag to `v2`, push, and the app is updated.
