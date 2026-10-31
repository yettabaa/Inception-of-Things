# 04 — Implementation plan

Follows the team plan PDF (Step 0 → 5). Roles: **A** leads P1 and the P3 infrastructure, **B** leads P2 and the P3 GitHub/app side; each reviews the other.
Legend: ✅ done in repo (static checks only) · ⬜ to do · 🔬 needs a real run on the defense machine.

## Step 0 — Preparation (both)
- ✅ Repo skeleton: `p1/ p2/ p3/ bonus/`, each with `scripts/` and `confs/`; `.gitignore` for `.vagrant/` and `node-token`.
- ⬜ Install on the defense machine/VM: VirtualBox + Vagrant (P1/P2). *Missing on this workstation.*
- ✅ Naming login `yettabaa` → `LOGIN` in `p1/Vagrantfile`, `p2/Vagrantfile`.
- ✅ `git init`, create `main`, work on feature branches (`feat/p1`, `feat/p2`, `feat/p3`), PR/review between A and B. Conventional commits.

## Step 1 — P1 (lead A, review B)
1. ✅ `p1/Vagrantfile` — two VMs, IPs, 1 CPU / 1024 MB.
2. ✅ `p1/scripts/server.sh` — kubectl, K3s server bound to `192.168.56.110`, token exported.
3. ✅ `p1/scripts/worker.sh` — K3s agent joined with the token.
4. 🔬 `cd p1 && vagrant up`; on the server: `kubectl get nodes -o wide` → 2× `Ready`, `.110`/`.111`.
5. 🔬 `ip a` to confirm the interface; `vagrant ssh <login>S` and `<login>SW` work without a password.
6. 🔬 B runs `vagrant destroy -f && vagrant up` from scratch and confirms.

Acceptance: the P1 checklist in `02-what-to-implement.md`.

## Step 2 — P2 (lead B, review A)
1. ✅ `p2/Vagrantfile` + `p2/scripts/server.sh` (K3s server, waits for Traefik, applies manifests).
2. ✅ `p2/confs/apps.yaml` — 3 Deployments/Services, app2 `replicas: 3`.
3. ✅ `p2/confs/ingress.yaml` — `app1.com`, `app2.com`, default → app3.
4. 🔬 Test: `curl -H "Host: app1.com" 192.168.56.110` → "Hello from app1."; `app2.com` → app2; no/other host → app3.
5. 🔬 Show `kubectl get all` (3 app2 pods) and `kubectl get ingress`.
6. 🔬 A rebuilds from scratch once.

## Step 3 — P3 (split)
**A**
1. ✅ `p3/scripts/install.sh` — Docker, kubectl, K3d `v5.9.0`, argocd CLI.
2. ✅ `p3/scripts/setup.sh` — cluster `iot` (`8888→80`), namespaces `argocd` + `dev`, Argo CD, Application.
3. ✅ `p3/confs/argocd-app.yaml` points at that repo.

**B**
4. ✅ Public GitHub repo `yettabaa/yettabaa-iot-app`.
5. ✅ `deployment.yaml`, `service.yaml`, `ingress.yaml` pushed at the repo root (v1).
6. ⬜ (Only if own app) build/push Docker Hub image `:v1` and `:v2` with visible differences, change `image:`.

**Both**
7. 🔬 `./install.sh` on a clean VM, re-login for the docker group, `./setup.sh`.
8. 🔬 `kubectl get ns`, `kubectl get pods -n dev`, `curl http://localhost:8888/` → `{"status":"ok","message":"v1"}`.
9. 🔬 Demo: `v1`→`v2`, commit, push, wait for sync (or *Refresh* in UI), `curl` → `v2`. Repeat until each of you can do it alone.

## Step 4 — Bonus (only if P1–P3 are flawless)
`bonus/`: namespace `gitlab`, Helm install of latest GitLab (needs ≥ 4–6 GB RAM for the VM), configure it for the cluster, repoint the Argo CD Application, re-run the v1→v2 demo against local GitLab. Written in `bonus/`, see `bonus/README.md`.

## Step 5 — Submission and defense prep
- ⬜ Double-check folder/file names against the subject tree (`p1`, `p2`, `p3`, `bonus`, `scripts`, `confs`).
- ⬜ Run the P3 install script live on a clean VM at least once.
- ⬜ Rehearse the explanations in `03-concepts-to-understand.md`.
- ⬜ Test on the machine that will be used for the defense.

## Known risks / things I could not verify here
| Risk | Why | Mitigation |
|------|-----|------------|
| Nothing was run end-to-end | No Vagrant/VirtualBox/k3d on this workstation; I did not install them without your OK | Run the 🔬 steps; fix anything they reveal |
| Synced folder needs VirtualBox guest additions | Used to pass the token (P1) and manifests (P2) | If the box lacks them, switch to `type: "rsync"` or `vagrant plugin install vagrant-vbguest` |
| Interface autodetect by IP | `ip -o -4 addr` + awk | Verify `--flannel-iface` in `journalctl -u k3s` |
| Argo CD `stable` manifest and K3s "latest" drift | Unpinned on purpose (subject: latest) | Pin versions if a defense-day regression appears |
| Running P3 inside a nested VM | K3d needs Docker; nested virt not required, but RAM ≥ 4 GB advisable | Give the P3 VM 2 CPU / 4 GB |
