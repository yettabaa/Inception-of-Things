# argocd-app.yaml

## apiVersion: argoproj.io/v1alpha1
which API group and version

## project: default

Where it is stored
- The Kubernetes API server stores every object in the cluster datastore. Normal Kubernetes uses etcd.
- K3s, which k3d runs, uses SQLite by default through a layer called kine, which makes SQLite look like etcd to Kubernetes.
- So default is one row-like record in that store. You never touch it directly, only through the API.

## server: https://kubernetes.default.svc 

- This is the address of a Kubernetes API server, which is the cluster to deploy into.
- kubernetes.default.svc is the cluster-internal DNS name of the kubernetes Service in the default namespace. Every cluster has it, and it points at that cluster's own API server.
- Argo CD runs inside the cluster, so this value means "the cluster I am running in". Argo CD uses its own service account to talk to it. No kubeconfig or credentials are needed.
- It is the same as the cluster named in-cluster in Argo CD's cluster list.
- To deploy to a different cluster you would register it with argocd cluster add and put its real API URL here.
- The name only resolves inside the cluster. From your host it means nothing, which is fine because Argo CD, not you, resolves it.

namespace: dev
- This is the namespace the app's objects (Deployment, Service, Ingress) are created in.
- It is a default. If a manifest in the Git repo sets its own metadata.namespace, that one wins. Argo CD only fills in dev for manifests with no namespace.
- Argo CD does not create it by default. setup.sh creates dev at line 18. If it were missing, the sync would fail with namespace "dev" not found, unless you add syncPolicy.syncOptions: [CreateNamespace=true].

## prune: true
- If you delete a file or object from Git (say ingress.yaml), the Ingress stays in the cluster.

# setup.sh

## kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

It runs as part of the kube-apiserver component inside your Kubernetes cluster.
This avoids the client-side annotation-size problem without unnecessarily forcing ownership conflicts.