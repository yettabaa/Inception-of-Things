# P1: K3s cluster with Vagrant (server + worker)

## vagrant

Vagrant is an open-source tool that helps us to automate the creation and management of Virtual Machines. In a nutshell, we can specify the configuration of a virtual machine in a simple configuration file, and Vagrant creates the same Virtual machine using just one simple command. It provides command-line interfaces to automate such tasks. 

Boot up / Create environment
```bash
vagrant up
```
Log into VM CLI
```bash
vagrant ssh
```
Check current folder status
```bash
vagrant status
```
Check system-wide Vagrant VMs
```bash
vagrant global-status
```
Gracefully turn off VM
```bash
vagrant halt
```
Completely wipe and delete VM
```bash
vagrant destroy -f
```

## k8s
https://www.geeksforgeeks.org/devops/kubernetes-architecture/
https://kubernetes.io/docs/concepts/architecture/

1. Master node (Control Plane)
The control plane components manage and control the entire Kubernetes cluster.
- kube-apiserver
- etcd
- kube-scheduler
- kube-controller-manager
- cloud-controller-manager (when using a cloud provider)
2. Worker node (Data Plane)
The node components run and manage the applications (Pods).
- kubelet
- kube-proxy
- Container Runtime (containerd, CRI-O, etc.)

3. What controllers run inside kube-controller-manager?
There are multiple controllers, each responsible for a different Kubernetes resource or behavior.
Controller	Responsibility
Deployment Controller	Manages Deployments and their ReplicaSets
ReplicaSet Controller	Maintains the desired number of Pods
Node Controller	Monitors node health
Job Controller	Ensures Jobs run to completion
Namespace Controller	Handles namespace lifecycle and deletion
ServiceAccount Controller	Manages ServiceAccounts

## k3s
k3s use docker by default ?
K3s comes with containerd bundled as its default container runtime.

https://docs.k3s.io/architecture


## Network

- **NAT (`enp0s3`)**: `10.0.2.15` on every VM. Internet access only, not usable between VMs.
- **Private network (`enp0s8`)**: the `192.168.56.x` address. This is the one K3s must use.

## cgroup

Cgroups ( **control groups** ) is a Linux kernel feature that limits, accounts for, and isolates the resource usage (such as CPU, memory, disk I/O, and network) of a collection of processes.

## The problem

Wiupthout extra flags, K3s picks the default-route interface (NAT). Nodes then show `INTERNAL-IP 10.0.2.15` and look `Ready`, but the cluster is broken:

- Pod-to-pod traffic between nodes fails.
- `kubectl logs` / `kubectl exec` on worker pods fail or hang.

`private_network` in the Vagrantfile only creates the interface. It does not tell K3s to use it.

## The fix: flags to pass to K3s

IFACE=$(ip -o -4 a | grep ${SERVER_IP} | awk '{print $2}')

Dynamically extract the interface holding the private IP (e.g., enp0s8 or eth1)
-o — output each interface on one line.
-4 — show IPv4 addresses only.
addr — show IP addresses assigned to interfaces.
show — display the information.

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
