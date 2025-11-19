# Motivation

This document outlines the key problems with the official ArgoCD ApplicationSet controller that motivated the creation of this alternative plugin-based implementation.

## Problems with the Official ApplicationSet Controller

### 1. No Clear Management Interface

When you apply an ApplicationSet directly (not as part of a parent Application), the controller creates all child Applications but you lose the clear management interface that ArgoCD provides for regular Applications. You can't easily see the ApplicationSet's status, sync it, or manage it through the ArgoCD UI in the same intuitive way as regular Applications.

### 2. Cannot Pause Controller Behavior

You cannot pause the ApplicationSet controller from force-syncing the generated Application manifests. This makes simple operations on child Applications extremely difficult:

- Enabling/disabling auto-sync on specific child Applications
- Changing target revision for testing or hotfixes
- Performing any manual operations without controller interference

To overcome this, you need to resort to problematic workarounds:
- Kill the entire controller (affects all ApplicationSets)
- Delete the ApplicationSet (risky, requires careful configuration of `preserveResourcesOnDeletion` and `applicationsSync` policies)
- Add complex `ignoreApplicationDifferences` configurations

### 3. No Diff Visibility

The ArgoCD UI cannot show meaningful diffs for ApplicationSet-managed Applications because the controller force-syncs them, so the UI assumes they're always in sync. This eliminates one of ArgoCD's most valuable features:

- Cannot see what changes the controller is about to apply
- Cannot review diffs before automatic application
- Cannot understand why an Application changed state
- Cannot debug configuration drift or issues

### 4. No Manual Sync with Options

Unlike the regular app-of-apps pattern, there's no way to manually sync all child Applications with sync options (like `--force`, `--replace`, `--prune`). This means:

- No bulk sync operations with custom sync options - common use case: bulk sync with or without RespectIgnoreDifferences option
- Missing the operational control that app-of-apps provides
- Forces you to manage each child Application individually and set complex policy on the ApplicationSet manifest to ignore those individual changes

## Solution Approach

This plugin-based implementation addresses these issues by leveraging ArgoCD's native Application management while providing ApplicationSet functionality through the Config Management Plugin system. The solution also leverages the app-of-apps pattern, maintaining the familiar ArgoCD operational model while delivering ApplicationSet capabilities without the operational limitations of the official controller.