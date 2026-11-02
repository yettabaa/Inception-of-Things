# 02 — What needs to be implemented

Each item maps to a requirement in the subject. Status reflects the repo as it is now.
"Written" = file exists and passed static checks (`bash -n`, `ruby -c`, YAML parse). **Nothing has been executed end-to-end yet** — see `04-implementation-plan.md` for the verification runs.

## Decisions taken (change in one place if you disagree)

| Decision | Value | Where |
|----------|-------|-------|
| Distro / box | Debian 13 — `bento/debian-13` (has a VirtualBox build) | `BOX` in both Vagrantfiles |
| Vagrant provider | VirtualBox | `config.vm.provider "virtualbox"` |
| Naming login | `reben-ha` (**placeholder — use the real login**) | `LOGIN` in both Vagrantfiles |
| VM resources | 1 CPU, 1024 MB | Vagrantfiles |
| P2 apps | `paulbouwer/hello-kubernetes:1.10`, one message per app | `p2/confs/apps.yaml` |
| P3 app | Wil's `wil42/playground` v1/v2, port 8888 | `p3/confs/dev-repo/manifests/` |

## P1 checklist

| # | Requirement | Implementation | Status |
|---|-------------|----------------|--------|
| 1 | 2 VMs, 1 CPU, ≤1024 MB | `p1/Vagrantfile` | written |
| 2 | Names `<login>S`, `<login>SW` | `LOGIN` variable | written |
| 3 | IPs .110 / .111, private network | `private_network ip:` | written |
| 4 | Passwordless SSH | Vagrant default (`vagrant ssh`) | built-in |
| 5 | K3s controller on S | `p1/scripts/server.sh` | written |
| 6 | K3s agent on SW, joined by token | `p1/scripts/worker.sh` (token via synced folder `node-token`) | written |
| 7 | `kubectl` installed | installed from dl.k8s.io in `server.sh` | written |
| 8 | Modern Vagrantfile | `Vagrant.configure("2")`, variables, shell provisioners | written |

Key details: `--node-ip` + `--flannel-iface` force K3s onto the `192.168.56.x` interface (otherwise it uses the NAT interface and the nodes report `10.0.2.15`).

## P2 checklist

| # | Requirement | Implementation | Status |
|---|-------------|----------------|--------|
| 1 | 1 VM `<login>S`, `.110`, K3s server | `p2/Vagrantfile`, `p2/scripts/server.sh` | written |
| 2 | 3 web apps | `p2/confs/apps.yaml` (Deployment + Service each) | written |
| 3 | App 2 has 3 replicas | `replicas: 3` on `app-two` | written |
| 4 | `app1.com` → app1, `app2.com` → app2, else app3 | `p2/confs/ingress.yaml` (Traefik; host-less last rule = default) | written |
| 5 | Show `get all` and `get ingress` in defense | commands in `03` / `04` | — |

## P3 checklist

| # | Requirement | Implementation | Status |
|---|-------------|----------------|--------|
| 1 | No Vagrant; K3d on the VM | `p3/scripts/setup.sh` (`k3d cluster create`) | written |
| 2 | Script installing Docker, K3d, tools | `p3/scripts/install.sh` | written |
| 3 | Namespaces `argocd` and `dev` | `setup.sh` | written |
| 4 | Argo CD installed + UI reachable | official `install.yaml`, port-forward, admin password printed | written |
| 5 | Public GitHub repo, login in its name | **manual** — contents prepared in `p3/confs/dev-repo/` | TODO (you) |
| 6 | App with `v1`/`v2` tags | `wil42/playground:v1` in `deployment.yaml` | written |
| 7 | Argo CD auto-deploys to `dev` | `p3/confs/argocd-app.yaml` (`automated`, `prune`, `selfHeal`) | written, needs real `repoURL` |
| 8 | `curl localhost:8888` returns v1, then v2 | k3d `-p 8888:80@loadbalancer` + Traefik Ingress in the repo | written |

## Bonus (do **not** start before P1–P3 are flawless)
Helm-install the latest GitLab into namespace `gitlab`, configure it for the cluster, point the Argo CD Application at the local GitLab repo, keep everything under `bonus/`. Folder skeleton exists; content intentionally not written yet.

## Manual steps nobody can automate for you
1. Pick the real login for `LOGIN`; put the same login in the GitHub repo name.
2. Create the public GitHub repo, copy `p3/confs/dev-repo/manifests/` into it, push.
3. Put its URL in `p3/confs/argocd-app.yaml` (`repoURL`).
4. Install VirtualBox + Vagrant on the host/VM that runs P1/P2 (not installed on this machine today; Docker, kubectl and helm are).
