# Installation Guide

This guide will walk you through installing the `appset` plugin.

## Prerequisites

- Kubernetes cluster with ArgoCD installed
- kubectl configured to access your cluster
- ArgoCD CLI installed - Optional

## Notes

- All resources are deployed to the `argocd` namespace
- Please read the manifests before applying.
- Change the manifests/move the logic to Gitops as you see fit

## Installation Steps

#### 1. Deploy the `appset-repo` service:

```sh
cat <<EOF | kubectl -n argocd apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: appset-repo
spec:
  replicas: 1
  selector:
    matchLabels:
      name: appset-repo
  template:
    metadata:
      labels:
        name: appset-repo
    spec:
      containers:
        - name: appset-repo
          image: ghcr.io/marxus/argocd-appset:v2.0.0
          args: [servegit]
          env:
            - name: APPSET_REFRESH_INTERVAL
              value: 3m
---
apiVersion: v1
kind: Service
metadata:
  name: appset-repo
spec:
  selector:
    name: appset-repo
  ports:
    - port: 80
      targetPort: 8080
EOF
```

#### 2. Add an ArgoCD account for the `appset` plugin:

```sh
cat <<EOF | kubectl -n argocd patch configmap argocd-cm --patch-file /dev/stdin
data:
  accounts.appset: apiKey
EOF
```

#### 3. Set up the required permissions for the `appset` account:

```sh
cat <<EOF | kubectl -n argocd patch configmap argocd-rbac-cm --patch-file /dev/stdin
data:
  policy.appset.csv: |
    p, appset, applicationsets, create, default/-, allow
    p, appset, applications, get, *, allow
    p, appset, projects, get, *, allow
EOF
```

#### 4. Generate an API token and store it as a secret to be passed to `appset-cmp` sidecar container:

```sh
# using CLI or via UI: http://argocd.example.com/settings/accounts/appset
ARGOCD_AUTH_TOKEN="$(argocd account generate-token --account appset)"

# this assumes the existence of `argocd-server` service and that "server.insecure: true" (not https)
ARGOCD_OPTS='--server argocd-server --plaintext'

cat <<EOF | kubectl -n argocd apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: appset-secret
stringData:
  ARGOCD_AUTH_TOKEN: $ARGOCD_AUTH_TOKEN
  ARGOCD_OPTS: $ARGOCD_OPTS
EOF
```

#### 5. Patch the repo-server to include the `appset-cmp` sidecar container (make sure `appset-secret` exists!):

```sh
cat <<EOF | kubectl -n argocd patch deployment argocd-repo-server --patch-file /dev/stdin
spec:
  template:
    spec:
      containers:
        - name: appset-cmp
          image: ghcr.io/marxus/argocd-appset:v2.0.0
          env:
            - name: APPSET_REFRESH_INTERVAL
              value: 3m
          envFrom:
            - secretRef:
                name: appset-secret
          volumeMounts:
            - name: var-files
              mountPath: /var/run/argocd
            - name: plugins
              mountPath: /home/argocd/cmp-server/plugins
            - name: appset-tmp
              mountPath: /tmp
      volumes:
        - name: appset-tmp
          emptyDir: {}
EOF
```
