Kubernetes Namespaces
Overview
A Namespace is a way to logically separate resources inside a Kubernetes cluster.

It allows you to organize applications into different environments or teams without creating separate clusters.

What does a Namespace isolate?
Feature	Namespace behavior
Resources	Groups resources separately
Naming	Same resource names can exist in different namespaces
RBAC	Permissions can be defined per namespace
Resource quotas	CPU and memory consumption can be limited
Network	Not automatically isolated; NetworkPolicies can restrict communication
Nodes	Namespaces share the cluster's worker nodes
Control plane	Namespaces share the same Kubernetes control plane

1. Authorization and roles
Yes! Kubernetes RBAC (Role-Based Access Control) works with namespaces.

For example:
- Developer A can manage resources in dev.
- Developer B can only read resources in dev.
- DevOps engineer can manage resources in both dev and prod.
Two important objects:
- Role: Defines permissions within a namespace.
- RoleBinding: Assigns a Role to a user, group, or ServiceAccount within a namespace.