# Demo Script

## Recording Requirement

The final live demo should be recorded on the local Windows machine inside WSL2 Ubuntu, not on the no-sudo Linux server. The Linux server is only for coding and static validation.

The live demo environment is:

- Windows
- WSL2 Ubuntu
- Docker Desktop with WSL integration enabled
- Conda environment `cloud`
- k3d-based Kubernetes cluster

## Exact Demo Order

### 1. Activate the Conda Environment

```bash
conda activate cloud
chmod +x scripts/*.sh
```

What to say:

`I am using the shared cloud Conda environment required by the project workflow.`

### 2. Prove Docker Access in WSL2

```bash
docker ps
```

What to say:

`This confirms that Docker Desktop WSL integration is working and that this machine can run live Kubernetes validation.`

### 3. Create the k3d Cluster

```bash
k3d cluster create dsaa4040-lab
k3d kubeconfig merge dsaa4040-lab --kubeconfig-merge-default --kubeconfig-switch-context
```

What to say:

`The live cluster for the demo is a k3d cluster named dsaa4040-lab running inside Docker.`

### 4. Show the Kubernetes Node

```bash
export BOOTSTRAP_KUBECONFIG="$HOME/.kube/config"
kubectl get nodes -o wide
```

What to say:

`The Kubernetes control plane is reachable from WSL2.`

### 5. Run the Environment Check

```bash
bash scripts/check-environment.sh
```

What to say:

`This script reports whether the current machine is ready for live validation and does not claim success if Docker or Kubernetes access is missing.`

### 6. Run Cluster Bootstrap

```bash
bash scripts/bootstrap-cluster.sh
```

What to say:

`The bootstrap script targets the k3d workflow by default and connects the repository automation to the live cluster.`

### 7. Onboard Team A

```bash
bash scripts/onboard-team.sh team-a
```

What to say:

`This applies namespace labels, pod security labels, RBAC, quotas, limits, network policies, and generates team-a kubeconfigs.`

### 8. Onboard Team B

```bash
bash scripts/onboard-team.sh team-b
```

What to say:

`This repeats the same automation for the second required tenant.`

### 9. Run the Automated Tests

```bash
bash scripts/run-tests.sh
```

What to say:

`The test suite first performs static validation and then runs live RBAC, quota, limit, and TCP-based network isolation tests because a real Kubernetes cluster is available in WSL2.`

### 10. Show the Test Evidence

```bash
ls -1dt artifacts/test-results/*
LATEST_RESULT="$(ls -1dt artifacts/test-results/* | head -n 1)"
echo "$LATEST_RESULT"
cat "$LATEST_RESULT/summary.txt"
```

What to say:

`All grading evidence is written to artifacts/test-results so the result is reproducible and inspectable after the demo.`

## Optional Follow-Up Shots

If time allows, show these after the main flow:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" exec -n team-a network-client -- \
  wget -q -T 5 -O - http://http-echo.team-b.svc.cluster.local
```

These reinforce:

- cross-tenant RBAC denial
- viewer read-only behavior
- cross-namespace TCP denial

## Closing Statement

`This platform is a soft multi-tenant teaching lab, not hard multi-tenancy. The static validation was done on the development server, and the full live Kubernetes validation was completed here in WSL2 with Docker Desktop and k3d.`
