# ArgoCD `appset` Plugin Flow

## Overview

`appset` mimics the functionality of the official `applicationset-controller` by leveraging ArgoCD's existing mechanisms (manifest caching, interval git polling, etc.). Instead of running a separate controller, it uses ArgoCD's native Git-based refresh cycles and Config Management Plugin system to achieve the same behavior within ArgoCD's established architecture.

## Flow Description

**1. Application Creation**
- An ArgoCD application is created using the `appset` plugin
- The application references a fake Git repository (`appset-repo`)

**2. Repository Change**
- `appset-repo` creates a new empty commit at a configured interval (`$APPSET_REFRESH_INTERVAL`)
- The `appset-repo` serves as a trigger mechanism rather than containing actual source code

**3. Hard Refresh Trigger**
- ArgoCD polls `appset-repo` at its own interval, upon new commit it triggers hard refresh for the application that uses the `appset` plugin

**4. ApplicationSet Processing**
- Hard refresh causes the invocation of manifest generation using the `appset-cmp` sidecar container
- The plugin receives the ApplicationSet specification via `$PARAM_SPEC`

**5. Application Generation**
- `appset-cmp` sidecar container runs `argocd appset generate` with the provided spec which generates the applications manifests
- These generated applications manifests are returned to ArgoCD for deployment

**6. Interval Enforcement**
- `appset-cmp` sidecar container also keep track of applications that are using the `appset` plugin
- It triggers a soft refresh at the configured interval (`$APPSET_REFRESH_INTERVAL`) to check if the commit has changed
- This ensures the interval is maintained even when ArgoCD is set to event-based or has a longer polling interval

## Key Insight

This creates a time-based refresh mechanism for ApplicationSets by using `appset-repo` as a periodic trigger, allowing ApplicationSets to re-evaluate their generators and create/update applications at regular intervals while staying within ArgoCD's native operational model.
