# 02 — What needs to be implemented

Each item maps to a requirement in the subject (`docs/subjects/en.subject.pdf`).

## Decisions taken (change in one place if you disagree)

| Decision | Value | Where |
|----------|-------|-------|
| Distro / box | Ubuntu 22.04 (`BOX` constant) | `p1/Vagrantfile`, `p2/Vagrantfile` |
| Vagrant provider | VirtualBox | `config.vm.provider "virtualbox"` |
| Naming login | `yettabaa` | `LOGIN` in both Vagrantfiles |
| VM resources | P1: 1 CPU, 1024 MB (subject advice) | Vagrantfiles |
| P2 apps | `paulbouwer/hello-kubernetes:1.10`, one message per app | `p2/confs/apps.yaml` |
| P3 app | Wil's `wil42/playground` v1/v2, port 8888 | GitHub repo `yettabaa/yettabaa-iot-app` |

## P1 checklist

| # | Requirement | Implementation |
|---|-------------|----------------|
| 1 | 2 VMs, 1 CPU, 512 or 1024 MB | `p1/Vagrantfile` |
| 2 | Names `<login>S`, `<login>SW` | `LOGIN` variable |
| 3 | IPs .110 / .111, private network | `private_network ip:` |
| 4 | Passwordless SSH | Vagrant default (`vagrant ssh`) |
| 5 | K3s controller on S | `p1/scripts/server.sh` |
| 6 | K3s agent on SW, joined by token | `p1/scripts/worker.sh` (token shared through `/vagrant/confs/node-token`, git-ignored) |
| 7 | `kubectl` installed | ships with K3s |
| 8 | Modern Vagrantfile | `Vagrant.configure("2")`, variables, shell provisioners |

Key details: `--node-ip` + `--flannel-iface` force K3s onto the `192.168.56.x` interface (otherwise it uses the NAT interface and the nodes report `10.0.2.15`).

## P2 checklist

| # | Requirement | Implementation |
|---|-------------|----------------|
| 1 | 1 VM `<login>S`, `.110`, K3s server | `p2/Vagrantfile`, `p2/scripts/server.sh` |
| 2 | 3 web apps | `p2/confs/apps.yaml` (Deployment + Service each) |
| 3 | App 2 has 3 replicas | `replicas: 3` on `app2-deployment` |
| 4 | `app1.com` → app1, `app2.com` → app2, else app3 | `p2/confs/ingress.yaml` (Traefik; host-less last rule = default) |
| 5 | Show `get all` and `get ingress` in defense | commands in `03` / `04` |

## P3 checklist

| # | Requirement | Implementation |
|---|-------------|----------------|
| 1 | No Vagrant; K3d on the VM | `p3/scripts/setup.sh` (`k3d cluster create`) |
| 2 | Script installing Docker, K3d, tools | `p3/scripts/install.sh` |
| 3 | Namespaces `argocd` and `dev` | `setup.sh` |
| 4 | Argo CD installed + UI reachable | official `install.yaml`, port-forward, admin password printed |
| 5 | Public GitHub repo, login in its name | `github.com/yettabaa/yettabaa-iot-app` (deployment, service, ingress) |
| 6 | App with `v1`/`v2` tags | `wil42/playground:v1` in its `deployment.yaml` |
| 7 | Argo CD auto-deploys to `dev` | `p3/confs/argocd-app.yaml` (`automated`, `prune`, `selfHeal`) |
| 8 | `curl localhost:8888` returns v1, then v2 | k3d `-p 8888:80@loadbalancer` + Traefik Ingress in the repo |

## Bonus

Helm-install the latest GitLab into namespace `gitlab`, configure it for the cluster, point the Argo CD Application at a local GitLab project. See `bonus/README.md`.
