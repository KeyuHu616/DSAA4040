# Testing Guide

## Purpose

This project now supports two explicit validation workflows:

- Workflow A: static validation on a no-sudo Linux server
- Workflow B: live Kubernetes deployment and testing in WSL2 Ubuntu with Docker Desktop and k3d

The Kubernetes platform design is the same in both cases. The difference is only what can actually be executed on the machine.

## Workflow A: No-Sudo Linux Server

Use this workflow when the server is only for coding and static checks and Docker access is unavailable or denied.

### What This Workflow Validates

- shell syntax for all project scripts
- required repository structure
- rendered tenant manifests for `team-a` and `team-b`
- YAML parsing with Python and PyYAML
- optional `kubectl --dry-run=client` when a client binary is available

### What This Workflow Does Not Validate

- live cluster bootstrap
- CSR approval against a Kubernetes API server
- real RBAC enforcement
- real `ResourceQuota` or `LimitRange` admission behavior
- real `NetworkPolicy` enforcement

### Exact Commands

```bash
conda activate cloud
chmod +x scripts/*.sh
bash scripts/check-environment.sh
bash scripts/static-validate.sh
bash scripts/run-tests.sh
```

Expected behavior:

- `bash scripts/static-validate.sh` writes `artifacts/test-results/static-validation.log`
- `bash scripts/run-tests.sh` runs static validation and then prints:

```text
Static validation completed; live Kubernetes validation is pending on WSL2 or another Docker/Kubernetes-enabled machine.
```

### Output Locations

- rendered manifests: `artifacts/rendered/`
- static validation log: `artifacts/test-results/static-validation.log`

## Workflow B: Local WSL2 Live Validation

Use this workflow on your local Windows machine with WSL2 Ubuntu.

### Required Local Setup

- Docker Desktop running on Windows
- Docker Desktop WSL integration enabled for your Ubuntu distribution
- Conda environment `cloud`
- k3d installed

If `k3d` is missing after `conda activate cloud`, install it in WSL2 with:

```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

### Exact Commands

If `k3d` is missing, install it once before the live workflow:

```bash
command -v k3d >/dev/null 2>&1 || curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

Compatibility note:

- the scripts prefer `BOOTSTRAP_KUBECONFIG`, then `KUBECONFIG`, then `$HOME/.kube/config`
- for the WSL2 + k3d path, keep `BOOTSTRAP_KUBECONFIG="$HOME/.kube/config"`
- optional K3s users should export `BOOTSTRAP_KUBECONFIG=/etc/rancher/k3s/k3s.yaml` explicitly

Main live workflow:

```bash
conda activate cloud
chmod +x scripts/*.sh
docker ps
k3d cluster create dsaa4040-lab --servers 1 --agents 1 --api-port 127.0.0.1:6550 --wait
k3d kubeconfig merge dsaa4040-lab --kubeconfig-merge-default --kubeconfig-switch-context
kubectl config set-cluster k3d-dsaa4040-lab --server=https://127.0.0.1:6550
export BOOTSTRAP_KUBECONFIG="$HOME/.kube/config"
kubectl get nodes -o wide
bash scripts/check-environment.sh
bash scripts/bootstrap-cluster.sh
bash scripts/onboard-team.sh team-a
bash scripts/onboard-team.sh team-b
bash scripts/run-tests.sh
```

### What `run-tests.sh` Does in Live Mode

1. Runs static validation first.
2. Verifies the cluster is reachable through `BOOTSTRAP_KUBECONFIG`.
3. Ensures `team-a` and `team-b` are onboarded.
4. Captures cluster state.
5. Runs RBAC tests.
6. Runs `ResourceQuota` and `LimitRange` tests.
7. Runs TCP-based `NetworkPolicy` tests.
8. Saves results under `artifacts/test-results/<timestamp>/`.

## Live Test Result Files

Each live run produces:

- `summary.txt`
- `rbac-tests.txt`
- `resource-tests.txt`
- `network-tests.txt`
- `cluster-state.txt`
- `rendered/`

`rendered/` contains the exact manifests used during that live run.

## RBAC Coverage

The live RBAC section checks the required acceptance cases:

- Developer A can create deployments in `team-a`
- Developer A can get pods in `team-a`
- Developer A can get pod logs in `team-a`
- Developer A cannot read or write `team-b`
- Developer A cannot touch quotas, network policies, rolebindings, namespaces, or secrets
- Viewer A can read in `team-a`
- Viewer A cannot mutate resources
- Viewer A cannot read secrets

## Resource Governance Coverage

The live resource section checks:

- a normal workload succeeds
- a pod without explicit resources receives default requests and limits
- an oversized pod is rejected by `LimitRange`
- a quota-exceeding workload is rejected by `ResourceQuota`

Expected injected defaults:

- `requests.cpu=250m`
- `requests.memory=256Mi`
- `limits.cpu=500m`
- `limits.memory=512Mi`

## Network Coverage

The live network section deploys:

- one HTTP server in `team-a`
- one HTTP server in `team-b`
- one client pod in each tenant

It then verifies:

- `team-a` can reach `team-a`
- `team-b` can reach `team-b`
- `team-a` cannot reach `team-b`
- `team-b` cannot reach `team-a`

The checks use `wget` over HTTP, not `ping`.

## Manual Re-Checks After a Live Run

Repeat the key TCP checks:

```bash
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" exec -n team-a network-client -- \
  wget -q -T 5 -O - http://http-echo.team-a.svc.cluster.local

kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" exec -n team-a network-client -- \
  wget -q -T 5 -O - http://http-echo.team-b.svc.cluster.local
```

Repeat RBAC spot checks:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i delete pods -n team-a
```

## Honesty Rule

Static validation on Workflow A is useful and required, but it is not a substitute for live Kubernetes validation. Only claim full validation after Workflow B succeeds in WSL2.
