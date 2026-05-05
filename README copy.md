# DSAA 4040 E3 Multi-Tenant Kubernetes Lab Platform

This repository implements a namespace-based soft multi-tenant Kubernetes lab platform for DSAA 4040 E3. The platform keeps the Kubernetes design fixed across all environments:

- namespace-per-tenant isolation
- CSR-based users and generated kubeconfigs
- least-privilege RBAC for `developer` and `viewer`
- `ResourceQuota`
- `LimitRange`
- `NetworkPolicy`
- Pod Security Admission labels
- onboarding and offboarding automation
- automated validation

The required tenants are:

- `team-a`
- `team-b`

## Repository Structure

```text
.
├── README.md
├── AGENTS.md
├── environment.yml
├── docs/
│   ├── proposal.md
│   ├── architecture.md
│   ├── rbac-matrix.md
│   ├── onboarding-guide.md
│   ├── testing-guide.md
│   ├── demo-script.md
│   └── ha-discussion.md
├── manifests/
│   ├── rbac/
│   ├── quota/
│   ├── limitrange/
│   ├── netpol/
│   ├── podsecurity/
│   └── test-workloads/
├── scripts/
│   ├── bootstrap-cluster.sh
│   ├── check-environment.sh
│   ├── onboard-team.sh
│   ├── offboard-team.sh
│   ├── issue-user-kubeconfig.sh
│   ├── static-validate.sh
│   └── run-tests.sh
└── artifacts/
    ├── kubeconfigs/
    ├── rendered/
    └── test-results/
```

## Conda Environment

Create and activate the shared project environment:

```bash
conda env create -f environment.yml
conda activate cloud
chmod +x scripts/*.sh
```

The environment includes:

- `python=3.11`
- `kubectl`
- `openssl`
- `jq`
- `yq`
- `curl`
- `wget`
- `make`
- `git`
- Python packages: `pyyaml`, `kubernetes`, `pytest`

Important note about `k3d`:

- this repository does not pin `k3d` through Conda because the common `k3d` Conda package name resolves to an unrelated 3D visualization package rather than the Kubernetes CLI
- for the WSL2 live workflow, install the real k3d CLI separately if `command -v k3d` is empty:

```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

## Workflow A: No-Sudo Linux Server

Use this workflow on a shared Linux server that is only meant for coding and static validation.

Assumptions:

- `sudo` is unavailable or not practical
- Docker may be installed but inaccessible
- no live Kubernetes cluster can be started locally when Docker permission is denied

What this workflow is for:

- editing manifests, scripts, and docs
- shell syntax checks
- repository structure checks
- rendering tenant YAML for `team-a` and `team-b`
- PyYAML validation
- optional `kubectl --dry-run=client` checks when the client is installed

What this workflow is not for:

- live Kubernetes deployment
- CSR approval against a real API server
- RBAC, quota, limit, and network enforcement tests

Exact commands:

```bash
conda activate cloud
chmod +x scripts/*.sh
bash scripts/check-environment.sh
bash scripts/static-validate.sh
bash scripts/run-tests.sh
```

Expected behavior:

- `scripts/static-validate.sh` writes `artifacts/test-results/static-validation.log`
- `scripts/run-tests.sh` falls back to static validation only when no live cluster is reachable
- `scripts/run-tests.sh` prints:

```text
Static validation completed; live Kubernetes validation is pending on WSL2 or another Docker/Kubernetes-enabled machine.
```

## Workflow B: Local WSL2 Live Validation

Use this workflow on your local Windows machine with WSL2 Ubuntu and Docker Desktop WSL integration enabled.

Prerequisites:

- Windows with WSL2 Ubuntu
- Docker Desktop installed and running
- Docker Desktop WSL integration enabled for the Ubuntu distribution
- Conda environment `cloud`
- Docker available inside WSL2
- k3d installed

Recommended preflight:

```bash
conda activate cloud
chmod +x scripts/*.sh
docker ps
bash scripts/check-environment.sh
```

### Cluster Bootstrap Commands

Fresh WSL2 command path from a new checkout:

If `k3d` is missing, install it once before the main workflow:

```bash
command -v k3d >/dev/null 2>&1 || curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

Main workflow:

```bash
conda activate cloud
chmod +x scripts/*.sh
docker ps
k3d cluster create dsaa4040-lab
k3d kubeconfig merge dsaa4040-lab --kubeconfig-merge-default --kubeconfig-switch-context
export BOOTSTRAP_KUBECONFIG="$HOME/.kube/config"
kubectl get nodes -o wide
bash scripts/check-environment.sh
bash scripts/bootstrap-cluster.sh
bash scripts/onboard-team.sh team-a
bash scripts/onboard-team.sh team-b
bash scripts/run-tests.sh
ls -1dt artifacts/test-results/*
```

Why the extra kubeconfig merge step matters:

- it makes the active `kubectl` context deterministic across k3d versions
- it ensures `kubectl get nodes` and later scripts point at `dsaa4040-lab`

The default `bootstrap-cluster.sh` mode is now `k3d`. It:

- reuses the existing `dsaa4040-lab` cluster if present
- creates the cluster if it is missing
- merges the k3d kubeconfig into `$HOME/.kube/config`
- switches to the `k3d-dsaa4040-lab` context
- waits for nodes to become Ready
- does not require `sudo` in the default `k3d` path

Existing functionality is preserved:

- `bash scripts/bootstrap-cluster.sh k3s`
- `bash scripts/bootstrap-cluster.sh minikube`

Important compatibility note:

- the optional `k3s` path still uses `sudo` and `/etc/rancher/k3s/k3s.yaml`
- the recommended WSL2 live workflow does not require either of those
- all tenant and test scripts now prefer `BOOTSTRAP_KUBECONFIG`, then `KUBECONFIG`, then `$HOME/.kube/config`, and only fall back to `/etc/rancher/k3s/k3s.yaml` as a last resort for K3s users

### Tenant Onboarding Commands

```bash
bash scripts/onboard-team.sh team-a
bash scripts/onboard-team.sh team-b
```

The onboarding script is idempotent. For each team it:

1. Creates the namespace if missing.
2. Applies `tenant=<team>` and project labels.
3. Applies Pod Security Admission labels.
4. Applies the developer `Role`.
5. Applies the developer `RoleBinding`.
6. Applies the viewer `RoleBinding`.
7. Applies the tenant `ResourceQuota`.
8. Applies the tenant `LimitRange`.
9. Applies the tenant `NetworkPolicy` objects.
10. Generates or refreshes:
   - `artifacts/kubeconfigs/<team>-developer.kubeconfig`
   - `artifacts/kubeconfigs/<team>-viewer.kubeconfig`

### Full Automated Validation

```bash
bash scripts/run-tests.sh
```

When a live cluster is reachable, `scripts/run-tests.sh`:

- runs static validation first
- onboards `team-a` and `team-b`
- executes RBAC allow and deny tests
- executes `ResourceQuota` and `LimitRange` tests
- executes TCP-based `NetworkPolicy` tests with `wget`
- saves a timestamped test bundle under `artifacts/test-results/`

## Generated Kubeconfig Usage

Developer example:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig get pods
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig create deployment demo --image=nginx
```

Viewer example:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig get pods
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig get services
```

The generated kubeconfigs default to the tenant namespace.

## RBAC Testing Commands

Positive checks:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i list services -n team-a
```

Negative checks:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get secrets -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get secrets -n team-a
```

## Quota and LimitRange Testing Commands

Normal workload:

```bash
sed 's|__TEAM__|team-a|g' manifests/test-workloads/normal-deployment.yaml.tpl \
  | kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig apply -f -
```

Default injection check:

```bash
sed 's|__TEAM__|team-a|g' manifests/test-workloads/defaulted-pod.yaml.tpl \
  | kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig apply -f -

kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig \
  get pod defaulted-workload -o jsonpath='{.spec.containers[0].resources}'
```

Oversized workload expected to fail:

```bash
sed 's|__TEAM__|team-a|g' manifests/test-workloads/oversized-pod.yaml.tpl \
  | kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig apply -f -
```

Quota-exceeding workload expected to fail:

```bash
sed 's|__TEAM__|team-a|g' manifests/test-workloads/quota-exceeded-pod.yaml.tpl \
  | kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig apply -f -
```

## NetworkPolicy Testing Commands

Same-namespace TCP checks:

```bash
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" exec -n team-a network-client -- \
  wget -q -T 5 -O - http://http-echo.team-a.svc.cluster.local

kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" exec -n team-b network-client -- \
  wget -q -T 5 -O - http://http-echo.team-b.svc.cluster.local
```

Cross-namespace TCP checks expected to fail:

```bash
kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" exec -n team-a network-client -- \
  wget -q -T 5 -O - http://http-echo.team-b.svc.cluster.local

kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" exec -n team-b network-client -- \
  wget -q -T 5 -O - http://http-echo.team-a.svc.cluster.local
```

`wget` is used intentionally because the assignment requires TCP-based validation and explicitly forbids using `ping` as proof.

## Cleanup Commands

Remove tenants:

```bash
bash scripts/offboard-team.sh team-a
bash scripts/offboard-team.sh team-b
```

Remove the k3d cluster:

```bash
k3d cluster delete dsaa4040-lab
```

## Troubleshooting

`docker ps` fails in WSL2:

- confirm Docker Desktop is running
- confirm WSL integration is enabled for the Ubuntu distribution
- re-open the WSL2 shell and retry

`bash scripts/check-environment.sh` says Docker is denied on the server:

- this is expected on Workflow A
- do not claim live Kubernetes validation passed from that machine
- use `bash scripts/static-validate.sh` only

`kubectl` cannot reach the cluster:

- confirm `BOOTSTRAP_KUBECONFIG="$HOME/.kube/config"` in the k3d workflow
- run `k3d kubeconfig merge dsaa4040-lab --kubeconfig-merge-default --kubeconfig-switch-context`
- run `kubectl --kubeconfig "$BOOTSTRAP_KUBECONFIG" cluster-info`
- run `kubectl config current-context`

Scripts are not executable after checkout:

- run `chmod +x scripts/*.sh`

CSR issuance fails:

- confirm the admin kubeconfig points to the live cluster
- inspect `kubectl get csr`

Cross-namespace traffic still succeeds:

- confirm you are using the live k3d or K3s cluster, not static validation mode
- inspect `kubectl get networkpolicy -n team-a` and `-n team-b`
- retest with `wget`, not `ping`

## Validation Status Policy

This repository distinguishes clearly between:

- static validation completed
- live Kubernetes validation completed

Do not claim the project is fully validated until the WSL2 live deployment and automated tests pass successfully.
