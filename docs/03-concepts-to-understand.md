# 03 — What you need to understand (defense study guide)

The learning guide says it plainly: **both teammates must be able to explain every concept**, evaluators can ask either of you anything.

## 1. Virtualization and Vagrant
- **Vagrant** describes VMs as code (`Vagrantfile`). A **provider** (VirtualBox) runs them; a **box** is the base OS image.
- `private_network ip:` gives a host-only NIC with a fixed IP; the first NIC is NAT (internet). That is why a VM has two interfaces.
- **Provisioning** = scripts run on first boot (`config.vm.provision "shell"`). Idempotent scripts = repeatable setup.
- Commands: `vagrant up`, `vagrant ssh <name>`, `vagrant halt`, `vagrant destroy -f`, `vagrant status`.

## 2. Kubernetes basics
- A **cluster** = **control plane** (API server, scheduler, controllers, datastore) + **nodes** that run workloads.
- In K3s terms: **server** node = control plane (can also run pods); **agent** node = worker only.
- A worker joins with the server URL (`https://<ip>:6443`) and a **node token** (`/var/lib/rancher/k3s/server/node-token`).
- `kubectl` talks to the API server using a kubeconfig (`/etc/rancher/k3s/k3s.yaml`).

## 3. K3s vs K3d (the subject says you MUST know this)
| | K3s | K3d |
|-|-----|-----|
| What | Lightweight, certified Kubernetes distribution (single binary) | A wrapper that runs K3s **inside Docker containers** |
| Runs on | Directly on a machine/VM (systemd service) | Docker (each node = a container) |
| Needs | A Linux host | Docker |
| Use here | P1, P2 (real VMs) | P3 (fast disposable clusters, port mappings) |
Both give the same Kubernetes API. K3s bundles Traefik, CoreDNS, local-path storage, metrics-server.

## 4. Workloads
- **Pod**: smallest unit, one or more containers.
- **ReplicaSet**: keeps N identical pods alive.
- **Deployment**: manages ReplicaSets, gives rolling updates/rollback. `replicas: 3` → app2.
- **Service**: stable virtual IP + DNS name in front of pods (selected by labels). `ClusterIP` is internal only.

## 5. Ingress (P2)
- An **Ingress** is an HTTP routing rule; an **Ingress controller** (Traefik in K3s) implements it.
- Flow: client → node IP:80 → Traefik → match `Host` header → Service → Pod.
- `app1.com` isn't real DNS: you fake it with `curl -H "Host: app1.com" 192.168.56.110` or `/etc/hosts`.
- The rule without a host acts as the **default backend** (app3).

## 6. Namespaces
Logical partitions of a cluster (`argocd`, `dev`, `gitlab` for bonus). Names are unique per namespace; `-n dev` selects one.

## 7. Docker image tagging (P3)
`repo/name:tag`. Tags (`v1`, `v2`) pin a precise build. **Don't use `latest`** for deployments you want reproducible: changing the tag in Git is what triggers the update.

## 8. GitOps and Argo CD (P3)
- **GitOps**: Git is the single source of truth for the desired cluster state.
- **Argo CD** runs in the cluster, watches the repo, compares to live state, and **syncs**. Its `Application` CRD says: repo + path + destination namespace + sync policy.
- `automated` = sync without clicking; `prune` = delete what was removed from Git; `selfHeal` = revert manual drift.
- Loop in the demo: edit `deployment.yaml` → `git push` → Argo CD detects (polls ~3 min by default, or click *Refresh*) → rolls out v2.

## 9. Network debugging toolbox
`ip a` (interfaces) · `ssh` · `curl -H "Host: ..." <ip>` · `kubectl get nodes -o wide` · `kubectl describe pod` · `kubectl logs`.

## 10. Bonus only
**Helm** (package manager for Kubernetes, charts + values) and GitLab on Kubernetes (heavy: several GB of RAM).

## Command cheat sheet for the defense

```bash
# P1
vagrant up && vagrant ssh <login>S
kubectl get nodes -o wide ; ip a show <iface>
# P2
kubectl get all ; kubectl get ingress
curl -H "Host: app1.com" 192.168.56.110 ; curl -H "Host: app2.com" 192.168.56.110 ; curl 192.168.56.110
# P3
kubectl get ns ; kubectl get pods -n dev ; curl http://localhost:8888/
sed -i 's/playground:v1/playground:v2/' deployment.yaml && git commit -am "v2" && git push
```

## Likely evaluator questions
1. What is the difference between K3s and K3d? 2. Server vs agent? 3. How does the worker authenticate? 4. What is an Ingress vs a Service? 5. Why does app3 answer unknown hosts? 6. Why are there 3 pods for app2 — who creates them? 7. What does Argo CD do that `kubectl apply` doesn't? 8. What does `selfHeal` do? 9. Why tag v1/v2 instead of latest? 10. Why two namespaces?
