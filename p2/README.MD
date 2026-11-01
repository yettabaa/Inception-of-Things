# Part 2 — K3s and Three Simple Applications

## Overview

The goal of this part is to deploy three web applications in a K3s cluster and make them accessible through a single IP address, depending on the requested hostname.

This project introduces the fundamental Kubernetes resources used to deploy applications and manage network traffic.
```text
                 ┌──────────────────────────┐
                 │       Deployment         │
                 │                          │
                 │     Desired replicas: 3  │
                 └────────────┬─────────────┘
                              │
                              ▼
                 ┌──────────────────────────┐
                 │       ReplicaSet         │
                 │                          │
                 │   Ensures 3 Pods exist  │
                 └────────────┬─────────────┘
                              │
                 ┌────────────┼────────────┐
                 │            │            │
                 ▼            ▼            ▼
           ┌──────────┐ ┌──────────┐ ┌──────────┐
           │  Pod 1   │ │  Pod 2   │ │  Pod 3   │
           │          │ │          │ │          │
           │  Nginx   │ │  Nginx   │ │  Nginx   │
           └─────┬────┘ └─────┬────┘ └─────┬────┘
                 │            │            │
                 └────────────┼────────────┘
                              │
                              ▼
                 ┌──────────────────────────┐
                 │         Service          │
                 │                          │
                 │   Stable network access │
                 │     to the 3 Pods        │
                 └────────────┬─────────────┘
                              │
                              ▼
                 ┌──────────────────────────┐
                 │     Internal Client     │
                 │       or Ingress        │
                 └──────────────────────────┘
```
## kubernetes yaml

In Kubernetes YAML, the kind field specifies the type of Kubernetes API resource (object) you want to create or manage.

```yaml
  kind: Pod
  kind: Deployment
  kind: ReplicaSet
  kind: Service
  kind: Ingress
  kind: ConfigMap
  kind: Secret
  kind: PersistentVolume
  kind: PersistentVolumeClaim
  kind: StatefulSet
  kind: DaemonSet
  kind: Job
  kind: CronJob
```

## Architecture

```text
                    Browser / Client
                           |
                           | HTTP request
                           | Host: app1.com
                           v
                 192.168.56.110:80
                           |
                           v
                  Ingress Controller
                       (Traefik)
                           |
                 +---------+---------+
                 |         |         |
              app1.com  app2.com   Other hosts
                 |         |         |
                 v         v         v
              Service   Service   Service
              app-one   app-two  app-three
                 |         |         |
                 v         v         v
              Pod(s)    3 Pods     Pod(s)
```

- `app1.com` routes to application 1.
- `app2.com` routes to application 2, which runs three replicas.
- Any other hostname routes to application 3.

## Kubernetes Concepts

### 1. ReplicaSet

A ReplicaSet ensures that the required number of identical Pods is running.

For example, if a Deployment specifies three replicas and one Pod fails, Kubernetes attempts to create a replacement.

**Key idea:** A ReplicaSet maintains the desired number of Pods.


### 2. Deployment

A Deployment manages ReplicaSets, so we usually create Deployments rather than managing ReplicaSets directly.

It allows Kubernetes to create and maintain the required number of Pods. It also supports rolling updates and rollbacks.

**Key idea:** A Deployment declares how the application should run.

### 3. Service

Pods are temporary: they can be deleted, replaced, or assigned different IP addresses.

A Service provides a stable network endpoint for accessing a group of Pods selected by labels.

```text
                  Kubernetes Service
                  Name: app-two
                  Type: ClusterIP
                  ClusterIP: 10.43.0.20
                  Port: 80
                         |
             +-----------+-----------+
             |           |           |
             v           v           v
       +-----------+ +-----------+ +-----------+
       |  Pod 1    | |  Pod 2    | |  Pod 3    |
       | app=two   | | app=two   | | app=two   |
       |           | |           | |           |
       | 10.42.1.2 | | 10.42.1.3 | | 10.42.1.4 |
       | Port 8080 | | Port 8080 | | Port 8080 |
       +-----------+ +-----------+ +-----------+
```

For example, the Service `app-two` selects the Pods belonging to application 2.

A Service can distribute traffic across its selected Pods.

Common Service types:

- `ClusterIP`: Makes a Service accessible inside the Kubernetes cluster only.
- `NodePort`: Exposes a Service through a port on each node's IP address.
- `LoadBalancer`: Exposes a Service through an external load balancer, typically provided by a cloud platform or another load-balancer implementation.

**Key idea:** A Service provides stable access to Pods.

### 4. Ingress

An Ingress defines HTTP/HTTPS routing rules for incoming traffic.

In this project, Traefik acts as the Ingress Controller that implements these rules.

```text
                 HTTP request
                       |
                       v
                 Traefik Ingress
                       |
          +------------+------------+
          |            |            |
      app1.com      app2.com     Other host
          |            |            |
          v            v            v
       app-one      app-two     app-three
       Service      Service     Service
```

The remaining rule can route unmatched hosts to `app-three`.

**Key idea:** Ingress routes incoming HTTP requests to the appropriate Service based on rules such as the hostname and URL path.
