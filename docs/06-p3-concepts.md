# Part 3 — Every concept, every line, and how it all connects

Files covered (current branch, the `main` version):
`p3/scripts/install.sh`, `p3/scripts/setup.sh`, `p3/confs/argocd-app.yaml`,
`p3/README.MD`. The app manifests live in an **external GitHub repo**
(`yettabaa/yettabaa-iot-app`, branch `main`, path `.`), which I have not read:
the notes about its content below are what the subject expects
(`wil42/playground` v1/v2 on port 8888), not something I verified.

**Goal of P3:** no Vagrant. Run K3d (K3s inside Docker), install Argo CD, and
let Argo CD deploy an app from a Git repo into namespace `dev`. Changing the
image tag `v1` → `v2` in Git must change the running app by itself (GitOps).

---

## 1. Big picture

```
        you                     GitHub repo (source of truth)
         │ git push v2           └─ manifests: Deployment (wil42/playground:v1)
         ▼                                       ▲
                                                 │ polls every ~3 min (or refresh)
┌────────────────── Docker ─────────────────────┼──────────────┐
│  k3d cluster "iot"  (K3s nodes = containers)   │              │
│                                                │              │
│  ns argocd:  repo-server ──clone──────────────┘              │
│              application-controller  compares Git vs cluster  │
│                    │ kubectl-apply equivalent (auto-sync)     │
│                    ▼                                          │
│  ns dev:     Deployment ─► Pod (wil42/playground)             │
│                                                              │
│  k3d loadbalancer :80  ◄── host :8888                        │
└───────────────────────────────────────────────────────────────┘
  curl http://localhost:8888/   →  {"status":"ok","message":"v1"}
```

The chain: **install.sh** gives you tools → **setup.sh** builds the cluster
and Argo CD → **argocd-app.yaml** tells Argo CD which repo to watch → Argo CD
creates the app in `dev` → you edit Git → Argo CD updates the app.

---

## 2. Concepts

### 2.1 Docker
Runs containers (isolated processes with their own filesystem). K3d needs it
because every "node" of the cluster is a Docker container.
- `usermod -aG docker $USER` lets you use docker without sudo, but only
  **after logging out and in again** (new group membership).

### 2.2 K3s vs K3d
- **K3s**: lightweight Kubernetes, one binary (used in P1/P2 inside VMs).
- **K3d**: a wrapper that runs K3s **inside Docker containers**. Creating a
  cluster takes seconds, no VM needed. It is not Kubernetes itself, only a
  launcher. Subject requires K3d here.
- A k3d cluster = containers `k3d-iot-server-0` (control plane + worker) and
  `k3d-iot-serverlb` (nginx load balancer in front).

### 2.3 kubectl and kubeconfig
`kubectl` talks to the API server using `~/.kube/config`. `k3d cluster create`
adds a context `k3d-iot` and switches to it, so the later `kubectl` calls in
the script hit the new cluster.

### 2.4 Namespace
Logical partition of a cluster: same names can exist twice, RBAC and quotas
can be per namespace, but it is **not** network isolation and nodes are
shared (see `README.MD`). Subject requires two:
- `argocd` — the tool itself.
- `dev` — the application it deploys.

### 2.5 Argo CD
A **GitOps** controller. It runs in the cluster, continuously compares the
desired state (YAML in Git) with the live state, and reconciles. Main pieces
(in `argocd`):
- `argocd-server` — API + web UI.
- `argocd-repo-server` — clones Git, renders manifests.
- `argocd-application-controller` — a StatefulSet that diffs and applies.
- `argocd-applicationset-controller` — generates many Applications from
  templates (unused here, part of the install).
- plus redis, dex (SSO), notifications.

### 2.6 CRD and the `Application` object
Argo CD installs Custom Resource Definitions. `Application`
(`argoproj.io/v1alpha1`) is one: a Kubernetes object meaning "deploy *this
path of this repo* into *that namespace of that cluster*".

### 2.7 GitOps
Git is the single source of truth. You never `kubectl apply` the app by
hand; you commit. Benefits: history, review, rollback = `git revert`, the
cluster can be rebuilt from Git.

### 2.8 Sync policy
- **manual** (default): Argo shows `OutOfSync`, you click Sync.
- **`automated`**: Argo syncs by itself when Git changes.
  - **`prune: true`**: resources deleted from Git are deleted from the cluster.
  - **`selfHeal: true`**: manual changes in the cluster (e.g. `kubectl scale`)
    are reverted to what Git says.

### 2.9 Ingress / Traefik / port mapping
K3s bundles Traefik. The k3d flag `-p "8888:80@loadbalancer"` publishes host
port 8888 onto port 80 of the k3d load-balancer container, which forwards to
Traefik, which routes by Ingress rules to the app Service. Without an
Ingress in the app repo, `curl localhost:8888` would fail.

### 2.10 Idempotency
The scripts can be re-run: they check if the cluster exists, use
`--dry-run | apply` for namespaces, and `apply` for everything else.

---

## 3. `install.sh`, line by line

```
1   #!/usr/bin/env bash        run with the bash found in PATH
3   set -euo pipefail          -e exit on error, -u unset var = error,
                               pipefail: a pipe fails if any stage fails
5-7 BLUE/GREEN/END             ANSI colour codes for printf
9-12 if [ "$EUID" -eq 0 ]      refuse root: the script uses sudo itself, and
                               `usermod -aG docker "${USER}"` must target the
                               real user, not root
14  apt-get update -y          refresh package index
15  apt-get install ca-certificates curl gnupg
                               certs for HTTPS, curl to download,
                               gnupg to dearmor Docker's key
18  if ! command -v docker     install only if missing (idempotent)
21  install -m 0755 -d /etc/apt/keyrings
                               create keyring dir with right permissions
22  curl .../linux/${ID}/gpg | gpg --dearmor -o docker.gpg
                               download Docker's signing key, convert to the
                               binary format apt accepts
23-24 echo "deb [arch=... signed-by=...] ... ${VERSION_CODENAME} stable" | tee
                               add Docker's apt repo, bound to that key
25  apt-get update             read the new repo
26  apt-get install docker-ce docker-ce-cli containerd.io
                               engine, CLI, container runtime
30  systemctl enable --now docker   start now + at boot
31  usermod -aG docker "${USER}"    docker without sudo (re-login needed)
34-42 kubectl                  find latest stable version at dl.k8s.io,
                               download the binary to /usr/local/bin, chmod +x
45-50 k3d                      official installer, pinned TAG=v5.9.0
53-59 argocd                   Argo CD CLI binary (a convenience; the UI and
                               kubectl are enough)
```

**Bug to know about:** lines 22–24 use `${ID}` and `${VERSION_CODENAME}`, but
the script never runs `. /etc/os-release`. With `set -u` it aborts with
"unbound variable" on a machine where Docker is **not** installed yet. It only
works if Docker already exists (the branch is skipped). Fix: add
`. /etc/os-release` before line 18. I did not change it.

Other notes: the `argocd` download uses `latest` (not pinned), `amd64` is
hardcoded, and `curl | bash` for k3d trusts the network.

---

## 4. `setup.sh`, line by line

```bash
3  set -euo pipefail
5-7 colours
9  if ! k3d cluster list iot >/dev/null 2>&1; then
```
`k3d cluster list iot` exits non-zero if no cluster named `iot` exists. Output
is discarded; only the exit code matters.

```bash
11 k3d cluster create iot -p "8888:80@loadbalancer" --wait
```
- `iot` — cluster name (context becomes `k3d-iot`).
- `-p "8888:80@loadbalancer"` — **host 8888 → port 80 of the load-balancer
  container**. The only way the host reaches apps inside Docker.
- `--wait` — return only when the control plane is ready, so the following
  `kubectl` calls don't race.
- Else branch (line 13): reuse, so reruns don't fail.

```bash
17 kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
18 ... dev
```
Plain `create namespace` fails if it exists. `--dry-run=client -o yaml` only
**prints** the YAML; `apply -f -` (stdin) creates it or leaves it unchanged.
The standard idempotent trick.

```bash
22 kubectl apply -n argocd --server-side --force-conflicts \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```
- `-f <URL>` — apply the official install manifest (CRDs, RBAC, Deployments,
  Services, ...).
- `-n argocd` — namespace for the namespaced objects.
- `--server-side` — the API server computes the merge. Needed because some
  Argo CRDs are larger than the 262144-byte limit of the
  `last-applied-configuration` annotation that client-side apply writes;
  without it you get "metadata.annotations: Too long".
- `--force-conflicts` — on a rerun, take ownership of fields changed by
  another manager instead of failing.
- `stable` tracks the latest release, so this is **not reproducible** over
  time. Pin a version tag for a stable defense.

```bash
27-29 kubectl -n argocd rollout status deployment/<x> --timeout=300s
```
Blocks until that Deployment's pods are ready (or fails after 300 s). It waits
for `argocd-server`, `repo-server`, `applicationset-controller`. Why: applying
the `Application` before its CRD and controller are ready fails or sits idle.
`argocd-application-controller` is a **StatefulSet**, so `rollout status
deployment/...` can't wait for it, and it is not waited on here.

```bash
33 kubectl apply -n argocd -f "./p3/confs/argocd-app.yaml"
```
Creates the `Application`. **The path is relative to the repo root**, so run
`./p3/scripts/setup.sh` from the root, not from `p3/` (from `p3/` the file is
not found). From here Argo CD takes over.

```bash
36-39 printf ... argocd-initial-admin-secret ... jsonpath='{.data.password}' | base64 -d
```
Argo generates a random admin password into Secret
`argocd-initial-admin-secret`. Secret data is base64, so `jsonpath` extracts
it and `base64 -d` decodes it. **It prints the password to the terminal**
(fine for a lab, not for logs). The printed `port-forward` command exposes the
UI: `svc/argocd-server` 443 → `localhost:8080` (self-signed cert: accept the
warning). `curl localhost:8888` is the app check.

---

## 5. `confs/argocd-app.yaml`, line by line

```yaml
apiVersion: argoproj.io/v1alpha1   # CRD group/version installed by Argo CD
kind: Application
metadata:
  name: playground                 # name shown in the UI
  namespace: argocd                # Application objects must live in argocd
spec:
  project: default                 # Argo "AppProject": permission boundary
                                   # (default allows everything)
  source:
    repoURL: https://github.com/yettabaa/yettabaa-iot-app.git
                                   # what to watch; public repo => no credentials
    targetRevision: main           # branch/tag/commit to follow
    path: .                        # folder in the repo with the manifests
  destination:
    server: https://kubernetes.default.svc
                                   # "the cluster Argo CD runs in"
                                   # (in-cluster API DNS name)
    namespace: dev                 # where objects are created
  syncPolicy:
    automated:
      prune: true                  # delete what disappeared from Git
      selfHeal: true               # undo manual drift
```

`destination.namespace` only applies to manifests that don't set their own
namespace. `dev` already exists (created by `setup.sh`); otherwise you would
add `syncOptions: [CreateNamespace=true]`.

Reconciliation: by default Argo polls Git about **every 3 minutes**. Force it
with the UI "Refresh" or
`kubectl annotate application playground -n argocd argocd.argoproj.io/refresh=hard --overwrite`.

---

## 6. The external app repo (what it must contain)

Not read by me. For the subject it needs, at `path: .`:
- a **Deployment** with `image: wil42/playground:v1` (port 8888),
- a **Service** (port 8888),
- an **Ingress** (Traefik) so `localhost:8888` reaches it.

Switching `v1` → `v2` in the Deployment and pushing is the demo.
`wil42/playground` answers `{"status":"ok","message":"v1"}` / `"v2"`.
The subject requires a public GitHub repo with your **login** in its name.

---

## 7. How everything connects (end to end)

1. **`install.sh`** — Docker, kubectl, k3d, argocd CLI on the host.
2. **`setup.sh` l.11** — `k3d cluster create` starts Docker containers
   running K3s, publishes host `:8888` → loadbalancer `:80`, writes the
   `k3d-iot` kubeconfig context.
3. **`setup.sh` l.17–18** — namespaces `argocd` and `dev`.
4. **`setup.sh` l.22** — Argo CD's CRDs + controllers appear in `argocd`.
5. **`setup.sh` l.27–29** — the script waits until they run.
6. **`setup.sh` l.33** — applies `argocd-app.yaml`: an `Application` object
   saying "watch the GitHub repo, deploy into `dev`".
7. **Argo CD** repo-server clones the repo; the controller diffs Git vs
   cluster, finds nothing in `dev`, and (because of `automated`) applies the
   Deployment/Service/Ingress. The pod starts.
8. **Traffic**: `curl localhost:8888` → Docker published port → k3d
   loadbalancer :80 → Traefik → Ingress rule → Service → pod. Answer: `v1`.
9. **GitOps demo**: edit the tag to `v2`, commit, push. Argo CD sees the new
   commit (≤3 min or refresh), diffs, updates the Deployment, a rolling update
   replaces the pod. `curl` now says `v2`. `selfHeal` would revert a manual
   `kubectl edit`; `prune` would delete anything you removed from Git.

---

## 8. Commands for the defense

```bash
kubectl get ns                                   # argocd and dev exist
kubectl get pods -n argocd                       # all Running
kubectl get pods -n dev                          # app Running
kubectl get application -n argocd                # Synced / Healthy
kubectl describe application playground -n argocd
kubectl get ingress -n dev
curl http://localhost:8888/                      # v1
# edit v1 -> v2 in the GitHub repo, push, then:
kubectl get pods -n dev -w                       # watch the rollout
curl http://localhost:8888/                      # v2
kubectl -n argocd port-forward svc/argocd-server 8080:443   # UI https://localhost:8080
docker ps                                        # the k3d containers
k3d cluster list
```

## 9. Likely defense questions

1. K3s vs K3d? Why does K3d need Docker?
2. What is GitOps? Who is the source of truth here?
3. What do `prune` and `selfHeal` do? Show selfHeal by scaling manually.
4. Why must the `Application` be in `argocd`, and where does the app go?
5. Why two namespaces? What is (and isn't) isolated by a namespace?
6. What does `-p 8888:80@loadbalancer` do?
7. Why `--server-side`? Why `--dry-run=client | apply`?
8. How does Argo CD learn about a new commit? (polling vs webhook)
9. What is `https://kubernetes.default.svc`?
10. Where did the admin password come from and how do you decode it?
11. How do you roll back? (`git revert` and push.)

---

## 10. Risks and things I did not verify

- `install.sh` unbound `ID` / `VERSION_CODENAME` bug (section 3): found by
  reading, not by running.
- `setup.sh` must be run from the repo root (path on line 33).
- It does not wait for the `argocd-application-controller` StatefulSet.
- The Argo CD manifest URL is `stable` (not pinned); the `argocd` binary is `latest`.
- The app repo content is unread; section 6 describes what the subject asks.
- Nothing on this branch was run; the `redmega` version of P3 (repo
  `RED-MEGA/reben-ha-iot`, with a `dev-repo` copy in the project) is the one I
  ran earlier.
