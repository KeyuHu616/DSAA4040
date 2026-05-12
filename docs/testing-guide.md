# Testing Guide

## Purpose

This project provides two validation levels:

- **Static validation** for repository integrity and manifest quality
- **Live validation** for real Kubernetes RBAC, admission control, and network isolation

The main grading target is the live validation workflow.

## Static Validation

Use static validation when you want to check the repository without depending on a running cluster.

```bash
conda activate cloud
chmod +x scripts/*.sh
bash scripts/static-validate.sh
```

Static validation checks:

- shell syntax for repository scripts
- required repository structure
- manifest rendering for `team-a` and `team-b`
- YAML parsing with PyYAML
- rendered workload security contexts
- optional `kubectl --dry-run=client` when a live cluster is reachable

Output:

- `artifacts/rendered/`
- `artifacts/test-results/static-validation.log`

## Live Validation

The recommended live path is WSL2 Ubuntu with Docker Desktop and `k3d`.

```bash
conda activate cloud
chmod +x scripts/*.sh
bash scripts/check-environment.sh
bash scripts/bootstrap-cluster.sh
bash scripts/onboard-team.sh team-a
bash scripts/onboard-team.sh team-b
bash scripts/run-tests.sh
```

## What the Live Suite Verifies

### RBAC

- developer access is limited to the developer’s own namespace
- viewer access is read-only
- tenant users cannot access Secrets
- tenant users cannot touch quotas, network policies, or RBAC objects
- generated kubeconfigs default to the correct namespace

### Resource Governance

- a normal workload succeeds
- a workload without explicit resources receives default requests and limits
- an oversized workload is rejected by `LimitRange`
- a quota-exceeding workload is rejected by `ResourceQuota`

### Network Isolation

- `team-a` can reach `team-a`
- `team-b` can reach `team-b`
- `team-a` cannot reach `team-b`
- `team-b` cannot reach `team-a`

All network checks use `wget` over HTTP instead of `ping`.

## Result Files

Each live run writes a timestamped directory containing:

- `summary.txt`
- `rbac-tests.txt`
- `resource-tests.txt`
- `network-tests.txt`
- `cluster-state.txt`

The summary file provides a quick pass/fail overview, while the per-topic logs show the exact checks.

## Manual Spot Checks

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i delete pods -n team-a
kubectl --kubeconfig "$HOME/.kube/config" exec -n team-a network-client -- \
  wget -q -T 5 -O - http://http-echo.team-a.svc.cluster.local
```

## Interpretation Rule

A successful static validation proves that the repository is well-formed. A successful live validation proves that the Kubernetes platform behavior matches the project claims. The submission should only claim complete validation after the live workflow succeeds.
