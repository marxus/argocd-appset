# argocd-appset

A extension for `argocd-repo-server` that uses `argocd appset generate` as a plugin

## Build

```sh
docker build -t <APPSET_IMAGE> .
docker push <APPSET_IMAGE>
```

or use the prebuilt docker image (arch supported `amd64` and `arm64`) from https://github.com/marxus/argocd-appset/pkgs/container/argocd-appset

## Installation

<b>plugin - "config management plugins" / "cmp" - adding a sidecar:</b><br/>
Documentation for this installation method, can be found here:<br/> https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins

### Installation Manifests

Add the following to `argocd-repo-server` deployment manifest, You can do so by patching the deployemnt, pass values to ArgoCD chart, etc...:

```yaml
containers:
  - name: appset
    image: ghcr.io/marxus/argocd-appset:v1.0.0 # <APPSET_IMAGE>
    securityContext: { runAsNonRoot: true, runAsUser: 999 }
    env:
      - name: APPSET_REFRESH_INTERVAL
        value: 3m
    volumeMounts:
      - name: var-files
        mountPath: /var/run/argocd
      - name: plugins
        mountPath: /home/argocd/cmp-server/plugins
      - name: appset
        mountPath: /tmp
volumes:
  - name: appset
    emptyDir: {}
```

### Additional Installation Manifests

The stdout stream producded by `argocd --core appset generate` will be used as the manifest for the ArgoCD application.<br/>
Certian permissions are required, here is a role and role binding to enable appset generation:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: <ARGOCD_NAMESPACE>
  name: appset
rules:
  - apiGroups: [""]
    resources: [configmaps]
    verbs: [list, get]
  - apiGroups: [""]
    resources: [secrets, services, pods]
    verbs: [list]
  - apiGroups: [""]
    resources: [pods/portforward]
    verbs: [create]
  - apiGroups: [argoproj.io]
    resources: [appprojects]
    verbs: [list, get]
  - apiGroups: [argoproj.io]
    resources: [applications]
    verbs: [list, get, patch]
  - apiGroups: [argoproj.io]
    resources: [applicationsets]
    verbs: [list]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: <ARGOCD_NAMESPACE>
  name: appset
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: appset
subjects:
  - kind: ServiceAccount
    name: argocd-repo-server
    namespace: <ARGOCD_NAMESPACE>
```

There is also a "fake" git for the application to consume, which controls the refresh interval, for that you'd need a simple *1* replica deployment and a service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  namespace: <ARGOCD_NAMESPACE>
  name: appset
spec:
  replicas: 1
  selector:
    matchLabels:
      name: appset
  template:
    metadata:
      labels:
        name: appset
    spec:
      containers:
        - name: appset
          image: ghcr.io/marxus/argocd-appset:v1.0.0 # <APPSET_IMAGE>
          securityContext: { runAsNonRoot: true, runAsUser: 999 }
          args: [servegit]
          env:
            - name: APPSET_REFRESH_INTERVAL
              value: 3m
---
apiVersion: v1
kind: Service
metadata:
  namespace: <ARGOCD_NAMESPACE>
  name: appset
spec:
  selector:
    name: appset
  ports:
    - port: 80
      targetPort: 8080
```

## Usage

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  namespace: <ARGOCD_NAMESPACE>
  name: my-appset
spec:
  project: my-project
  destination: # this is usually the destination for app of apps.
    name: in-cluster
    namespace: <ARGOCD_NAMESPACE>
  source:
    repoURL: http://appset # value should be the same as the service name...
    path: .
    plugin:
      name: appset # must specify the cmp's name
      env:
        # regular applicationset spec. some attributes only have meaning for the applicationset controller,
        # so they might be ignored during generation. usually they are not required since we have a real app
        # owning the generated output having better more flexiable alternatives.
        - name: SPEC
          value: |
            generators: ...
            goTemplate: ...
            goTemplateOptions: ...
            template: ...
            templatePatch: ...
```
