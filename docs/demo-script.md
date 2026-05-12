# Demo Script

## Goal

This script provides a clean grading-oriented demo for the final E3 submission. The recommended environment is WSL2 Ubuntu with Docker Desktop and a `k3d` cluster.

## Demo Flow

### 1. Activate the Conda environment

```bash
conda activate cloud
chmod +x scripts/*.sh
```

What to say:

`The repository uses the shared cloud Conda environment for reproducible tooling.`

### 2. Show environment readiness

```bash
bash scripts/check-environment.sh
```

What to say:

`This confirms whether Docker, kubectl, and a live Kubernetes cluster are reachable from the current shell.`

### 3. Bootstrap the cluster

```bash
bash scripts/bootstrap-cluster.sh
kubectl get nodes -o wide
```

What to say:

`The project uses a lightweight k3d-backed K3s cluster for reproducible local validation.`

### 4. Onboard Team A and Team B

```bash
bash scripts/onboard-team.sh team-a
bash scripts/onboard-team.sh team-b
```

What to say:

`Onboarding applies namespace labels, RBAC, ResourceQuota, LimitRange, NetworkPolicy, and generates tenant kubeconfigs.`

### 5. Show generated kubeconfigs

```bash
ls -1 artifacts/kubeconfigs
kubectl config view --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig --minify -o jsonpath='{.contexts[0].context.namespace}'; echo
kubectl config view --kubeconfig artifacts/kubeconfigs/team-b-viewer.kubeconfig --minify -o jsonpath='{.contexts[0].context.namespace}'; echo
```

What to say:

`The tenant kubeconfigs default to the correct namespace and map to simulated tenant users.`

### 6. Run the automated tests

```bash
bash scripts/run-tests.sh
```

What to say:

`The test suite runs static validation first and then executes live RBAC, resource-governance, and TCP-based network isolation checks.`

### 7. Show test evidence

```bash
LATEST_RESULT="$(ls -1dt artifacts/test-results/* | head -n 1)"
echo "${LATEST_RESULT}"
cat "${LATEST_RESULT}/summary.txt"
```

What to say:

`All validation evidence is stored under artifacts/test-results so the grader can inspect the results after the demo.`

### 8. Optional spot checks

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig "$HOME/.kube/config" exec -n team-a network-client -- \
  wget -q -T 5 -O - http://http-echo.team-b.svc.cluster.local
```

What to say:

`These spot checks reinforce cross-tenant RBAC denial, viewer read-only behavior, and cross-namespace TCP denial.`

## Closing Statement

`This platform is a soft multi-tenant teaching lab, not hard multi-tenancy. The implementation demonstrates namespace-based isolation, RBAC, resource governance, network isolation, and automated onboarding in a reproducible single-node Kubernetes environment.`
