# 01 — The project explained

Sources: `docs/en.subject.pdf` (the official 42 subject, v4.0) and `docs/Inception-of-Things (IoT) Learning Guide and Team Task Plan.pdf` (our team plan).

## What is Inception-of-Things?

A **system-administration** project. It is a first, *minimal* introduction to **Kubernetes (K8s)**. You build three progressively harder environments, always inside a **virtual machine**, and you defend them live on **your own computer**.

The idea in one sentence: *learn to run a tiny Kubernetes cluster, expose apps through an Ingress, then let Git drive deployments automatically (GitOps).*

## The three parts (must be done in order)

| Part | Folder | Tools | What you prove |
|------|--------|-------|----------------|
| **P1** | `p1/` | Vagrant + K3s | Two VMs form a cluster: one controller, one worker |
| **P2** | `p2/` | Vagrant + K3s + Ingress | One VM serves 3 apps, chosen by the HTTP `Host` header |
| **P3** | `p3/` | Docker + K3d + Argo CD + GitHub | A `git push` changes the running app (v1 → v2) with no manual deploy |
| Bonus | `bonus/` | Helm + GitLab | Replace GitHub with a GitLab running *inside* the cluster |

### P1 — K3s and Vagrant
- 2 VMs, latest stable distro of your choice, **1 CPU / 512 MB (or 1024 MB)** each.
- Names = a team member's login + `S` (server) and `SW` (server worker), e.g. `wilS`, `wilSW`.
- Static IPs on the private network: `192.168.56.110` (server), `192.168.56.111` (worker).
- Passwordless SSH (`vagrant ssh` does this).
- K3s in **controller mode** on the server, **agent mode** on the worker; `kubectl` installed.
- Vagrantfile written "according to modern practices" (no deprecated syntax, variables, provisioning scripts).
- Success looks like: `kubectl get nodes -o wide` → both nodes `Ready`, internal IPs `.110` and `.111`.

### P2 — K3s and three simple applications
- **One** VM, `<login>S`, IP `192.168.56.110`, K3s in server mode.
- 3 web apps of your choice. **App 2 has 3 replicas.**
- Request to `192.168.56.110` with `Host: app1.com` → app1; `Host: app2.com` → app2; anything else → app3 (default).
- The **Ingress is not shown in the subject screenshots on purpose** — you must show it to evaluators.

### P3 — K3d and Argo CD (no Vagrant)
- Install **K3d** on your VM (needs Docker). A **script** must install all tools — it is run during the defense.
- Two namespaces: one for **Argo CD**, one called **`dev`** holding the app.
- The app is deployed **automatically by Argo CD from a public GitHub repo**; the repo name must contain a team member's login.
- App has two tags **`v1` and `v2`**: Wil's `wil42/playground` (port 8888, returns `{"status":"ok","message":"v1"}`) or your own public Docker Hub image with visible differences.
- Defense demo: change `v1` → `v2` in the repo, push, Argo CD syncs, `curl http://localhost:8888/` now answers `v2`.

### Bonus — GitLab (only graded if the mandatory part is *flawless*)
- Latest GitLab, running **locally** in a namespace named **`gitlab`**, configured to work with the cluster.
- Everything from P3 must work against that local GitLab. All files in `bonus/`.

## Required repository layout

```
.
├── p1/    Vagrantfile  scripts/  confs/
├── p2/    Vagrantfile  scripts/  confs/
├── p3/    scripts/  confs/
└── bonus/ (optional) Vagrantfile  scripts/  confs/
```

Scripts go in `scripts/`, configuration files in `confs/`. Only what is in the Git repo is evaluated.

## How the pieces fit (big picture)

```
P1: [wilS controller .110] <--token--> [wilSW agent .111]     (a cluster, by hand)
P2: Host --HTTP--> .110 --> Traefik Ingress --> app1 | app2 (x3) | app3
P3: Host --git push--> GitHub <--sync-- Argo CD (in K3d) --deploys--> app in ns "dev" <-- curl :8888
```

## Pitfalls explicitly called out
- Subject screenshots use `eth0/eth1`; modern distros use `enp0s8` etc. Check with `ip a`.
- The evaluation is on **the evaluated group's machine** — test on the machine you will defend on.
- Everything must run in a VM; configuration lives in the repo, nothing "only on my laptop".
