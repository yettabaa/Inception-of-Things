# P1: K3s cluster with Vagrant (server + worker)

## vagrant

Vagrant is an open-source software tool created by HashiCorp for building, managing, and distributing portable virtualized development environments

Boot up / Create environment
vagrant up

Log into VM CLI
vagrant ssh

Check current folder status
vagrant status

Check system-wide Vagrant VMs
vagrant global-status

Gracefully turn off VM
vagrant halt

Restart & reload configuration
vagrant reload

Completely wipe and delete VM
vagrant destroy -f

## Network

- **NAT (`enp0s3`)**: `10.0.2.15` on every VM. Internet access only, not usable between VMs.
- **Private network (`enp0s8`)**: the `192.168.56.x` address. This is the one K3s must use.

## cgroup

Cgroups ( **control groups** ) is  =a Linux kernel feature that limits, accounts for, and isolates the resource usage (such as CPU, memory, disk I/O, and network) of a collection of processes.

## The problem

Wiupthout extra flags, K3s picks the default-route interface (NAT). Nodes then show `INTERNAL-IP 10.0.2.15` and look `Ready`, but the cluster is broken:

- Pod-to-pod traffic between nodes fails.
- `kubectl logs` / `kubectl exec` on worker pods fail or hang.

`private_network` in the Vagrantfile only creates the interface. It does not tell K3s to use it.

## The fix: flags to pass to K3s

| Flag                                     | Where  | Purpose                                          | Without it                            |
| ---------------------------------------- | ------ | ------------------------------------------------ | ------------------------------------- |
| `--write-kubeconfig-mode 644`          | server | Makes `k3s.yaml` readable by non-root          | `kubectl` needs `sudo`            |
| `--node-ip <IP>`                       | both   | IP the node announces                            | `INTERNAL-IP` is `10.0.2.15`      |
| `--advertise-address <IP>`             | server | IP the API server advertises                     | Wrong API endpoint inside the cluster |
| `--flannel-iface <IFACE>`              | both   | Interface used for the VXLAN tunnel              | Cross-node pod traffic breaks         |
| `--server https://192.168.56.110:6443` | worker | Control plane to join                            | Agent cannot register                 |
| `--token <TOKEN>`                      | worker | Join secret (shared via `/vagrant/node-token`) | Join rejected (401)                   |

## `curl ... | sh -s -` explained

| Piece                | Meaning                                                                      |
| -------------------- | ---------------------------------------------------------------------------- |
| `-s`               | Silent, no progress bar                                                      |
| `-f`               | Fail on HTTP errors instead of piping an error page into `sh`              |
| `-L`               | Follow redirects (`get.k3s.io` redirects)                                  |
| `INSTALL_K3S_EXEC` | Selects `server` or `agent` mode                                         |
| `sh -s -`          | Read the script from stdin; everything after `-` goes to the K3s installer |
