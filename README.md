# argocd-appset

A extension for `argocd-repo-server` that uses `argocd appset generate` as a plugin

## Build

```sh
docker build -t <ARGOCD_APPSET_IMAGE> .
docker push <ARGOCD_APPSET_IMAGE>
```

## Installation

<b>plugin - "config management plugins" / "cmp" - adding a sidecar:</b><br/>
Documentation for this installation method, can be found here:<br/> https://argo-cd.readthedocs.io/en/stable/operator-manual/config-management-plugins

### Installation Manifests

Add the following to `argocd-repo-server` deployment manifest, You can do so by patching the deployemnt, pass values to ArgoCD chart, etc...:

```yaml
containers:
  - name: appset-cmp
    image: <ARGOCD_APPSET_IMAGE>
    securityContext: { runAsNonRoot: true, runAsUser: 999 }
    env:
      - name: APPSET_CMP_SERVEGIT_ADDR
        value: 127.0.0.1:4040
      - name: APPSET_CMP_REFRESH_INTERVAL
        value: 1m
    volumeMounts:
      - name: var-files
        mountPath: /var/run/argocd
      - name: plugins
        mountPath: /home/argocd/cmp-server/plugins
      - name: appset-cmp
        mountPath: /tmp
volumes:
  - name: appset-cmp
    emptyDir: {}
```

### Additional Installation Manifests

The stdout stream producded by `argocd --core appset generate` will be used as the manifest for the ArgoCD application.<br/>
Certian permissions are required, here is a role and role binding to enable appset generation (required only if `argocd-repo-server` service account doesn't have such permission from beforehand):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: appset-cmp }
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
    resources: [applications, applicationsets]
    verbs: [list]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: appset-cmp }
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: appset-cmp
subjects:
  - kind: ServiceAccount
    name: argocd-repo-server
    namespace: <ARGOCD_NAMESPACE>
```

## Usage

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-appset
spec:
  project: my-project
  destination: # this is usually the destination for app of apps.
    name: in-cluster
    namespace: argocd
  source:
    repoURL: http://127.0.0.1:4040 # configurable via APPSET_CMP_SERVEGIT_ADDR
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
