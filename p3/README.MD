# Part 3 – Fundamental Concepts

## 1. k3d

k3d is a lightweight tool that runs K3s Kubernetes clusters inside Docker containers.

Instead of creating virtual machines, k3d uses Docker containers to simulate Kubernetes nodes.

A k3d cluster can contain:
- **Server nodes:** Run the Kubernetes control plane components.
- **Agent nodes:** Run application workloads.
- **Load balancer:** Routes requests to the server nodes.

Example:

```bash
k3d cluster create test --servers 1 --agents 2
```

This creates:
- 1 server node.
- 2 agent nodes.
- 1 load balancer container.

### Is it really Docker inside Docker?

This is generally called nested containerization.

- Docker runs the K3s node containers.
- Inside each K3s node, K3s uses containerd to run application containers.
- The inner containers share the host's Linux kernel; they don't run separate operating system kernels.

## 2. Kubernetes Namespaces

A Namespace is a way to logically separate resources inside a Kubernetes cluster.

It allows us to organize applications into different environments or teams without creating separate clusters.

### What does a Namespace isolate?

| Feature | Namespace behavior |
|---|---|
| Resources | Groups resources separately |
| Naming | Same resource names can exist in different namespaces |
| RBAC | Permissions can be configured per namespace |
| Resource quotas | CPU and memory consumption can be limited |
| Network | Not isolated by default; NetworkPolicies can restrict communication |
| Nodes | Namespaces share the same worker nodes |
| Control plane | Namespaces share the same cluster control plane |

### Authorization and Roles (RBAC)

Kubernetes RBAC (Role-Based Access Control) allows us to control who can access and manage resources.

For example:
- Developer A can manage resources in `dev`.
- Developer B can only read resources in `dev`.
- DevOps engineer can manage resources in both `dev` and `prod`.

Two important objects:

- **Role:** Defines permissions within a namespace.
- **RoleBinding:** Assigns a Role to a user, group, or ServiceAccount within a namespace.

## ArgoCD

Argo CD is a GitOps continuous delivery (CD) tool for Kubernetes.

GitOps is an operational framework that applies DevOps practices—such as version control, code review, and CI/CD—to infrastructure and application automation. It uses a Git repository as the single source of truth for the desired state of a system.

## 3. K3s Multi-Server Architecture

K3s supports multiple server nodes to provide high availability (HA).

In a multi-server cluster:
- Each server runs the Kubernetes control plane components.
- The servers share cluster state through a common datastore.
- Agent nodes connect to the server nodes to run application workloads.

### Important components

- **kube-apiserver:** Exposes the Kubernetes API.
- **etcd:** Stores the cluster state and configuration.
- **kube-scheduler:** Assigns new Pods to suitable nodes.
- **kube-controller-manager:** Ensures the actual cluster state matches the desired state.
- **kubelet:** Manages Pods on each node.
- **kube-proxy:** Handles Service networking rules.

In K3s, the control plane components are packaged together and run as a single K3s server process.

### High Availability (HA)

For embedded etcd HA, we generally need at least 3 server nodes.

An odd number of etcd members is recommended because etcd uses quorum to maintain consistency.

A load balancer can distribute requests between the available server nodes.

## 4. Database Management in K3s

K3s needs a datastore to store Kubernetes cluster information, such as:
- Nodes and their status.
- Pods and Deployments.
- Services and ConfigMaps.
- Secrets and cluster configuration.

### Supported datastores

K3s supports different datastore options:

| Datastore | Usage |
|---|---|
| SQLite | Default for a single-server cluster |
| Embedded etcd | Recommended for HA clusters |
| External MySQL | External database |
| External PostgreSQL | External database |
| External etcd | External etcd cluster |

### Application databases

There is an important difference between the Kubernetes datastore and an application database.

For example, if we deploy a PostgreSQL database for our application, we can:

- Deploy PostgreSQL inside the cluster using a StatefulSet and PersistentVolumeClaim (PVC).
- Use an external database hosted outside the cluster.

**Important:** PersistentVolumes (PV) and PersistentVolumeClaims (PVC) allow databases to store data beyond the lifecycle of individual Pods.

K3s provides Local Path Provisioner by default, which can automatically create local storage for PVCs. However, local storage is tied to a node and does not automatically provide high availability.

## Useful k3d Commands

### 1. Cluster management

```bash
# Create a cluster
k3d cluster create test

# Create a cluster with 1 server and 2 agents
k3d cluster create test --servers 1 --agents 2

# List clusters
k3d cluster list

# Get cluster information
k3d cluster get test

# Delete a cluster
k3d cluster delete test

# Stop a cluster
k3d cluster stop test

# Start a cluster
k3d cluster start test
```

### 2. Node management

```bash
# Add an agent node
k3d node create agent-2 --cluster test

# Add a server node
k3d node create server-2 --cluster test --role server

# List nodes
k3d node list

# Delete a node
k3d node delete agent-2
```

### 3. Port mapping

```bash
# Create a cluster and expose port 8080
k3d cluster create test -p "8080:80@loadbalancer"
```

Format:

`HOST_PORT:CONTAINER_PORT@NODE_TYPE`

- HOST_PORT: Port on your machine.
- CONTAINER_PORT: Port inside the cluster node.
- NODE_TYPE: Node receiving the port mapping (e.g. loadbalancer).

### 4. Image management

```bash
# Import a local Docker image into the cluster
k3d image import nginx:latest -c test

# Import multiple images
k3d image import nginx:latest redis:latest -c test
```

### 5. Kubernetes configuration

```bash
# Update kubeconfig for a cluster
k3d kubeconfig merge test --kubeconfig-switch-context

# Display kubeconfig
k3d kubeconfig get test
```

### 6. Debugging

```bash
# Display cluster information
k3d cluster list

# List all Docker containers created by k3d
docker ps

# View logs of a node container
docker logs k3d-test-server-0

# Inspect a node container
docker inspect k3d-test-server-0
```

### 7. Help

```bash
# General help
k3d --help

# Cluster commands
k3d cluster --help

# Command-specific help
k3d cluster create --help
```