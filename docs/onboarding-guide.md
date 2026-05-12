# Onboarding Guide

## Goal

This guide explains how to onboard a tenant namespace and generate working kubeconfigs for the tenant developer and viewer users.

## Prerequisites

- a reachable Kubernetes cluster
- NetworkPolicy enforcement enabled in the cluster runtime
- an admin kubeconfig
- `kubectl`
- `openssl`

For the recommended `k3d` workflow:

```bash
export BOOTSTRAP_KUBECONFIG="$HOME/.kube/config"
```

The scripts resolve the bootstrap kubeconfig in this order:

1. `BOOTSTRAP_KUBECONFIG`
2. `KUBECONFIG` when it points to one file
3. `$HOME/.kube/config`

## Required Tenants

```bash
bash scripts/onboard-team.sh team-a
bash scripts/onboard-team.sh team-b
```

The onboarding script is idempotent. Re-running it refreshes namespace labels, policy objects, and generated kubeconfigs.

## What Onboarding Applies

For each tenant, the script applies:

1. namespace creation and labels
2. Pod Security Admission labels
3. the developer `Role`
4. the developer `RoleBinding`
5. the viewer `RoleBinding`
6. the tenant `ResourceQuota`
7. the tenant `LimitRange`
8. the tenant `NetworkPolicy` objects
9. developer and viewer kubeconfigs

## Generated Files

The public kubeconfig outputs are:

- `artifacts/kubeconfigs/team-a-developer.kubeconfig`
- `artifacts/kubeconfigs/team-a-viewer.kubeconfig`
- `artifacts/kubeconfigs/team-b-developer.kubeconfig`
- `artifacts/kubeconfigs/team-b-viewer.kubeconfig`

Supporting key and certificate material is written under:

```text
artifacts/kubeconfigs/.generated/
```

## Verification

Check namespace labels:

```bash
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get namespace team-a --show-labels
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get namespace team-b --show-labels
```

Check tenant isolation objects:

```bash
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get resourcequota -n team-a
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get limitrange -n team-a
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get networkpolicy -n team-a
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get rolebinding -n team-a
```

Check kubeconfig default namespaces:

```bash
kubectl config view --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig --minify -o jsonpath='{.contexts[0].context.namespace}'; echo
kubectl config view --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig --minify -o jsonpath='{.contexts[0].context.namespace}'; echo
```

Check identity resolution:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth whoami
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth whoami
```

## Additional Tenants

The same script can onboard another namespace-shaped tenant:

```bash
bash scripts/onboard-team.sh team-c
```

The generated users will follow the same convention:

- `team-c-developer`
- `team-c-viewer`
