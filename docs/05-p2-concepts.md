# Part 2 — Every concept you need to understand

Based on the files currently in `p2/` on this branch:
`Vagrantfile`, `scripts/server.sh`, `confs/apps.yaml`, `confs/ingress.yaml`.

**Goal of P2:** one VM running K3s (server mode) with 3 web apps. The same IP
(`192.168.56.110`) serves a different app depending on the `Host` header:

| Request | Answer |
|---|---|
| `Host: app1.com` | app1 |
| `Host: app2.com` | app2 (3 replicas) |
| anything else | app3 (default) |

---

## 1. The big picture (data flow)

```
curl -H "Host: app2.com" 192.168.56.110
        │
        ▼
VM port 80  ──►  Traefik (Ingress controller, built into K3s)
                    │  reads Ingress rules, matches Host header
                    ▼
              Service app2-service (port 80, stable virtual IP)
                    │  load-balances over pods with label app=app2
                    ▼
        Pod 1 / Pod 2 / Pod 3  (container port 8080)
```

Everything below explains one box of this diagram.

---

## 2. Vagrant concepts (the `Vagrantfile`)

| Line | Concept |
|---|---|
| `Vagrant.configure("2")` | Config format version 2 (the only current one). |
| `config.vm.box = "ubuntu/jammy64"` | A **box** is a pre-built VM image (Ubuntu 22.04). Downloaded once, reused. |
| `config.vm.define "<login>S"` | Names a machine inside the file. Needed to have several VMs (P1 has two). |
| `vm.hostname` | OS hostname inside the VM. The subject requires `<login>S`. |
| `vm.network "private_network", ip:` | **Host-only network** (VirtualBox). Gives the VM a fixed IP reachable from your host only, e.g. `192.168.56.110`. VirtualBox host-only range is `192.168.56.0/24`. |
| `vm.provider "virtualbox"` | Provider-specific settings: `name` (name in VirtualBox GUI), `cpus`, `memory` (MB). Subject asks 1 CPU / 512–1024 MB; this file uses 2 / 2048. |
| `synced_folder "./confs", "/confs"` | Host folder mounted in the VM, so the script can `kubectl apply -f /confs/...`. |
| `vm.provision "shell", path:` | **Provisioning**: runs a script *once*, on first `vagrant up` (or `vagrant provision`). This is how K3s gets installed automatically. |

Commands: `vagrant up`, `vagrant ssh`, `vagrant halt`, `vagrant destroy -f`,
`vagrant provision`, `vagrant status`.

**Gotcha:** two projects using the same VirtualBox VM name collide
(`A VirtualBox machine with the name ... already exists`). Use a different
`vb.name` in P1 and P2 (or destroy one first).

---

## 3. The provisioning script (`scripts/server.sh`)

```bash
set -euo pipefail
```
- `-e` stop on first error, `-u` error on unset variable, `-o pipefail`
  a pipeline fails if any stage fails. Makes failures loud.

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - --node-ip ... --write-kubeconfig-mode 644
```
- `curl -sfL`: silent, fail on HTTP error, follow redirects.
- Pipes the official K3s installer into `sh`. `sh -s -` means "read script
  from stdin, pass the rest as arguments".
- `INSTALL_K3S_EXEC="server"`: run K3s in **server** mode (control plane).
- `--node-ip`: the IP the node advertises. Without it, on Vagrant K3s may
  pick the NAT interface (`10.0.2.15`), which is the same on every VM and
  not reachable from the host.
- `--write-kubeconfig-mode 644`: make `/etc/rancher/k3s/k3s.yaml` readable
  by the non-root `vagrant` user, so `kubectl` works without `sudo`.

```bash
kubectl apply -f /confs/apps.yaml
kubectl apply -f /confs/ingress.yaml
```
- **Declarative** deployment: you describe the desired state in YAML, `apply`
  makes the cluster match it. Re-running is safe (idempotent).

**Known race:** right after install the node may not be registered yet, so
`kubectl wait --for=condition=Ready node` can say "no matching resources
found". Wait until `kubectl get nodes` returns a line first.

---

## 4. Kubernetes concepts

### 4.1 K3s
Lightweight, single-binary Kubernetes (by Rancher/SUSE). Bundles
containerd, Flannel (networking), CoreDNS, **Traefik** (ingress) and a
local-path storage provisioner. Server = control plane + can run pods.
Ships `kubectl` as a symlink to itself.

### 4.2 Cluster, node
A cluster is a set of nodes. P2 has **one node** (the VM) that is both
control plane and worker.

### 4.3 Pod
Smallest deployable unit: one or more containers sharing network and
storage. Pods are **ephemeral**: they die and get new IPs. You almost never
create them by hand.

### 4.4 Deployment (and ReplicaSet)
Declares *"I want N identical pods of this template"*.
- `replicas: 3` on app2 → Kubernetes always keeps 3 pods alive. Delete one
  and a new one appears (self-healing).
- A Deployment creates a **ReplicaSet**, which creates the pods. Changing
  the pod template (e.g. image tag) creates a new ReplicaSet → rolling update.
- **`selector.matchLabels`** must match **`template.metadata.labels`**:
  that's how the Deployment knows which pods are its own.

Your three Deployments are identical except the name, the label
(`app: app1/2/3`), the `MESSAGE` env var and (for app2) `replicas: 3`.

### 4.5 Labels and selectors
Key/value tags on objects. Services and Deployments find pods only through
label selectors. Typo in a label = Service with no endpoints = 503/404.

### 4.6 Container image & env
- `paulbouwer/hello-kubernetes:1.10`: a tiny web app that prints a message
  and the **pod name** it runs on. Useful to *see* load balancing on app2.
- `containerPort: 8080`: documentation only; it does not open anything.
- `env: MESSAGE`: the app shows this text. This is how each app is told apart.

### 4.7 Service
A stable name + virtual IP (ClusterIP) in front of changing pods.
- `selector: {app: app1}` → forwards to all ready pods with that label.
- `port: 80` is what clients use; `targetPort: 8080` is the pod's port.
- Kube-proxy load-balances (round-robin-ish) across pods → this is why app2
  with 3 replicas shows different pod names on repeated requests.
- Default type is **ClusterIP**: reachable only inside the cluster. That's
  why we need an Ingress.

### 4.8 Ingress
An HTTP routing **rule set** (L7). It is just data; something must read it.
- `ingressClassName: traefik`: tells which controller owns this Ingress.
- `rules[].host`: match on the HTTP `Host` header.
- `paths[].path: /` + `pathType: Prefix`: match every URL starting with `/`.
- `backend.service`: where to send matching traffic.
- **A rule with no `host`** matches everything not matched by another rule →
  this is the **default app (app3)**. More specific host rules win.

### 4.9 Ingress controller (Traefik)
The actual reverse proxy that implements Ingress objects. K3s installs
Traefik in `kube-system` and exposes it on the node's ports 80/443 via the
built-in **ServiceLB (klipper-lb)**. No external load balancer is needed,
which is why `192.168.56.110:80` works.

### 4.10 Namespace
Logical grouping. P2 uses `default`. Traefik lives in `kube-system`.

### 4.11 kubectl commands to know
```
kubectl get nodes -o wide
kubectl get pods,svc,ingress -A
kubectl get deploy
kubectl describe ingress ingress
kubectl get endpoints            # are the services wired to pods?
kubectl logs deploy/app1-deployment
kubectl delete pod <name>        # watch it come back
kubectl scale deploy app1-deployment --replicas=2
```

---

## 5. Networking concepts

- **Host header / virtual hosting**: one IP + port can serve many sites. The
  client says which one in `Host:`. This is the whole trick of P2.
- **DNS vs Host header**: `app1.com` is not a real DNS entry for you.
  Either send the header by hand
  (`curl -H "Host: app1.com" http://192.168.56.110`) or add it to `/etc/hosts`:
  `192.168.56.110 app1.com app2.com`. The default app answers for any other
  name/IP.
- **Private (host-only) network**: only your machine and the VMs see
  `192.168.56.0/24`.
- **NAT adapter**: every VirtualBox VM also has a NAT NIC (`10.0.2.15`) for
  internet access. Don't confuse it with the private one.
- **Port 80 vs 8080 vs 6443**: 80 = Traefik (public entry), 8080 = app
  container, 6443 = Kubernetes API server.

---

## 6. How to test and what to expect

```bash
cd p2 && vagrant up
vagrant ssh <login>S -c "sudo kubectl get all,ingress"

curl -H "Host: app1.com" 192.168.56.110   # → Hello from app1.
curl -H "Host: app2.com" 192.168.56.110   # → Hello from app2.  (pod name changes)
curl                     192.168.56.110   # → Hello from app3.
curl -H "Host: nope.com" 192.168.56.110   # → Hello from app3.
```

Defense-ready checks:
- `kubectl get pods` shows **5 pods** (1 + 3 + 1) all `Running`.
- `kubectl get ingress` shows 3 rules and the node IP in `ADDRESS`.
- Delete an app2 pod and show it is recreated.

---

## 7. Likely defense questions

1. Why is app3 the default? → The Ingress rule without `host`.
2. What is the difference between a Pod, a Deployment and a Service?
3. Why 3 replicas for app2 and how do you prove it? → 3 pods, changing pod
   name in the page.
4. What does Traefik do, and who installed it? → K3s, built in.
5. What does `--node-ip` do and why is it needed in Vagrant?
6. What happens if the selector label and pod label differ?
7. Why does `curl 192.168.56.110` work with no load balancer? → ServiceLB.
8. What is `--write-kubeconfig-mode 644` for?
9. Difference between K3s server and agent? (P1 uses both, P2 only server.)
10. What is idempotency and why is `kubectl apply` idempotent?

---

## 8. Notes about the current files

- `Vagrantfile` here uses `LOGIN = "yettabaa"` and `ubuntu/jammy64` — this is
  the `main` branch version. The `redmega` branch uses `reben-ha` and
  `bento/debian-13`. Pick one login: the subject requires the VM names to
  be `<login>S`.
- `vb.cpus = 2, memory = 2048` is above the subject's minimum (1 CPU,
  512–1024 MB). It works but is heavier than needed.
- Mounting `./confs` to `/confs` is correct for P2 (the script applies the
  YAMLs from there).
