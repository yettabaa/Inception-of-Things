# Part 2 — K3s and Three Simple Applications

## Overview

The goal of this part is to deploy three web applications in a K3s cluster and make them accessible through a single IP address, depending on the requested hostname.

This project introduces the fundamental Kubernetes resources used to deploy applications and manage network traffic.

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
              app1      app2      app3
                 |         |         |
                 v         v         v
              Pod(s)    3 Pods     Pod(s)
```

- `app1.com` routes to application 1.
- `app2.com` routes to application 2, which runs three replicas.
- Any other hostname routes to application 3.

## Kubernetes Concepts

### 1. Deployment

A Deployment manages the desired state of an application.

It allows Kubernetes to create and maintain the required number of Pods. It also supports rolling updates and rollbacks.

Example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
        - name: app
          image: paulbouwer/hello-kubernetes:1.10
          ports:
            - containerPort: 8080
```

**Key idea:** A Deployment declares how the application should run.

### 2. ReplicaSet

A ReplicaSet ensures that the required number of identical Pods is running.

For example, if a Deployment specifies three replicas and one Pod fails, Kubernetes attempts to create a replacement.

```text
Deployment
    |
    v
ReplicaSet
    |
    +---- Pod 1
    +---- Pod 2
    +---- Pod 3
```

A Deployment manages ReplicaSets, so we usually create Deployments rather than managing ReplicaSets directly.

**Key idea:** A ReplicaSet maintains the desired number of Pods.

### 3. Service

Pods are temporary: they can be deleted, replaced, or assigned different IP addresses.

A Service provides a stable network endpoint for accessing a group of Pods selected by labels.

```text
             Service: app2-service
                    |
          +---------+---------+
          |         |         |
          v         v         v
        Pod 1     Pod 2     Pod 3
```

For example, the Service `app2-service` selects the Pods belonging to application 2.

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
       app1         app2        app3
       Service      Service     Service
```

Example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress
spec:
  ingressClassName: traefik
  rules:
    - host: app1.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app1-service
                port:
                  number: 80

    - host: app2.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app2-service
                port:
                  number: 80
```

The remaining rule can route unmatched hosts to `app3-service`.

**Key idea:** Ingress routes incoming HTTP requests to the appropriate Service based on rules such as the hostname and URL path.



