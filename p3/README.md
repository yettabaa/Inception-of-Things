# Part 3: K3d and Argo CD

## Layout

- `scripts/install.sh`: Docker, kubectl, k3d, argocd CLI (binaries follow the host architecture).
- `scripts/setup.sh`: k3d cluster `iot` (host 8888 -> Traefik), namespaces `argocd` and `dev`, Argo CD, the Application.
- `confs/argocd-app.yaml`: Argo CD Application watching the public GitHub repo (`repoURL`).
- `confs/app/`: the manifests that live at the root of that GitHub repo (deployment, service, ingress).
- `app/`: the application behind `absaid/playground:v1` and `:v2`. Multi-arch (amd64 + arm64),
  answers `{"status":"ok", "message": "<version>"}` on port 8888 like Wil's playground.

## Build and publish the app images

```sh
docker login
docker buildx create --name multi --driver docker-container --bootstrap
for v in v1 v2; do
  docker buildx build --builder multi --platform linux/amd64,linux/arm64 \
    --build-arg VERSION=$v -t absaid/playground:$v --push p3/app
done
```

## Run

```sh
./scripts/install.sh      # once, then log out/in for the docker group
./scripts/setup.sh        # prints the Argo CD admin password
curl http://localhost:8888/      # {"status":"ok", "message": "v1"}
```

Change `v1` to `v2` in the GitHub repo's `deployment.yaml`, push, and Argo CD rolls the new version out.
