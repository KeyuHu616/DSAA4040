# Onboarding Guide

## Goal

This guide describes how to create tenant namespaces and issue working kubeconfigs for tenant users with the provided automation.

## Prerequisites

- a running Kubernetes cluster
- NetworkPolicy enforcement enabled by the CNI
- an admin kubeconfig
- `kubectl`
- `openssl`

If you are using K3s, the default admin kubeconfig is usually:

```bash
export BOOTSTRAP_KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

If you are using Minikube:

```bash
export BOOTSTRAP_KUBECONFIG="$HOME/.kube/config"
```

If you are using the recommended WSL2 + k3d live workflow:

```bash
export BOOTSTRAP_KUBECONFIG="$HOME/.kube/config"
```

The tenant scripts prefer:

1. `BOOTSTRAP_KUBECONFIG`
2. `KUBECONFIG` when it points to one file
3. `$HOME/.kube/config`

For the WSL2 + k3d workflow, this means they use `$HOME/.kube/config` by default.
If you use the optional K3s workflow instead, export `BOOTSTRAP_KUBECONFIG=/etc/rancher/k3s/k3s.yaml` explicitly before running the tenant scripts.

## Onboard the Required Tenants

```bash
./scripts/onboard-team.sh team-a
./scripts/onboard-team.sh team-b
```

The script is idempotent. Re-running it refreshes tenant labels, policies, and user kubeconfigs.

## What the Script Applies

For the requested team, the script:

1. Applies the namespace manifest from `manifests/podsecurity/namespace.yaml.tpl`.
2. Applies the developer `Role` from `manifests/rbac/developer-role.yaml.tpl`.
3. Applies the developer `RoleBinding`.
4. Applies the viewer `RoleBinding`.
5. Applies the tenant `ResourceQuota`.
6. Applies the tenant `LimitRange`.
7. Applies the tenant `NetworkPolicy` objects.
8. Calls `scripts/issue-user-kubeconfig.sh` for `developer` and `viewer`.

## Generated Artifacts

The public kubeconfig files required by the assignment are:

- `artifacts/kubeconfigs/team-a-developer.kubeconfig`
- `artifacts/kubeconfigs/team-a-viewer.kubeconfig`
- `artifacts/kubeconfigs/team-b-developer.kubeconfig`
- `artifacts/kubeconfigs/team-b-viewer.kubeconfig`

Supporting certificate material is stored under:

```text
artifacts/kubeconfigs/.generated/
```

## Verification Commands

Check the namespace labels:

```bash
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get namespace team-a --show-labels
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get namespace team-b --show-labels
```

Check the tenant control objects:

```bash
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get resourcequota -n team-a
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get limitrange -n team-a
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" get networkpolicy -n team-a
```

Check the issued user identity:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth whoami
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth whoami
```

## Onboarding Another Team

The same script can onboard another namespace-shaped tenant:

```bash
./scripts/onboard-team.sh team-c
```

The generated users will be:

- `team-c-developer`
- `team-c-viewer`

Their certificate subjects will be:

- `CN=team-c-developer, O=team-c`
- `CN=team-c-viewer, O=team-c`
