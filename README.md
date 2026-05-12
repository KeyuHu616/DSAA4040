# DSAA4040 E3 Multi-Tenant Kubernetes Lab Platform

This repository contains a submission-focused implementation of the DSAA 4040 Engineering Project E3:

**Design and Implement a Multi-Tenant Kubernetes Lab Platform with RBAC and Resource Isolation**

The platform is intentionally scoped as a **namespace-based soft multi-tenant lab** for teaching and grading. It demonstrates:

- three roles: platform admin, tenant developer, tenant viewer
- per-team namespaces for `team-a` and `team-b`
- tenant-local RBAC without `ClusterRoleBinding` for tenant users
- `ResourceQuota` and `LimitRange`
- enforced `NetworkPolicy`
- Pod Security Admission labels
- automated onboarding, offboarding, kubeconfig issuance, and testing

## Repository Layout

```text
.
├── README.md
├── report.md
├── AGENTS.md
├── requirements.md
├── environment.yml
├── Makefile
├── docs/
├── manifests/
├── scripts/
└── artifacts/
```

## Recommended Environment

Primary validated workflow:

- Windows host
- WSL2 Ubuntu
- Docker Desktop with WSL integration enabled
- Conda environment `cloud`
- `k3d` cluster backed by K3s

The repository also keeps script-level support for direct `k3s` or `minikube`, but the recommended grading path is the `k3d` workflow because it is the simplest to reproduce.

## Prerequisites

Create or refresh the Conda environment:

```bash
conda env create -f environment.yml || conda env update -f environment.yml --prune
conda activate cloud
chmod +x scripts/*.sh
```

Required tools for the main workflow:

- `kubectl`
- `openssl`
- `curl`
- `wget`
- Docker Desktop access from WSL2
- `k3d`

Install `k3d` once if needed:

```bash
command -v k3d >/dev/null 2>&1 || curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

## Fast Reproduction

Run the complete grading path from the repository root:

```bash
conda activate cloud
chmod +x scripts/*.sh
bash scripts/check-environment.sh
bash scripts/bootstrap-cluster.sh
bash scripts/onboard-team.sh team-a
bash scripts/onboard-team.sh team-b
bash scripts/run-tests.sh
```

Expected outcome:

- a reachable single-node `k3d` Kubernetes lab cluster
- onboarded namespaces `team-a` and `team-b`
- generated tenant kubeconfigs under `artifacts/kubeconfigs/`
- rendered manifests under `artifacts/rendered/`
- automated test evidence under `artifacts/test-results/`

## What Each Script Does

`scripts/check-environment.sh`

- verifies the active Conda environment
- checks required command availability
- reports whether Docker and a live Kubernetes cluster are reachable

`scripts/bootstrap-cluster.sh`

- defaults to the `k3d` runtime
- creates or reuses the `dsaa4040-lab` cluster
- merges the cluster kubeconfig into `$HOME/.kube/config`
- normalizes the API server address for WSL2 loopback access

`scripts/onboard-team.sh <team>`

- creates the namespace if needed
- applies namespace labels and Pod Security labels
- applies RBAC, `ResourceQuota`, `LimitRange`, and `NetworkPolicy`
- issues or refreshes the developer and viewer kubeconfigs

`scripts/offboard-team.sh <team>`

- deletes the tenant namespace
- deletes related CSRs
- removes generated local kubeconfig artifacts for that tenant

`scripts/run-tests.sh`

- runs static validation first
- runs live RBAC, resource-governance, and TCP-based network tests when a cluster is reachable
- writes timestamped evidence files into `artifacts/test-results/`

## Generated Kubeconfigs

After onboarding, the repository generates:

- `artifacts/kubeconfigs/team-a-developer.kubeconfig`
- `artifacts/kubeconfigs/team-a-viewer.kubeconfig`
- `artifacts/kubeconfigs/team-b-developer.kubeconfig`
- `artifacts/kubeconfigs/team-b-viewer.kubeconfig`

The kubeconfigs default to the user namespace and use CSR-issued client certificates with these identity conventions:

- `CN=<team>-developer, O=<team>`
- `CN=<team>-viewer, O=<team>`

Quick usage examples:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig get pods
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig get services
```

## RBAC Validation Commands

Developer A allowed:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods/log -n team-a
```

Developer A denied:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i create deployments -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i update resourcequotas -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i update networkpolicies -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i create rolebindings -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i patch namespaces team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get secrets -n team-a
```

Viewer A allowed and denied:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get pods -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i list services -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i delete pods -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get pods -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get secrets -n team-a
```

## Quota and LimitRange Validation

Run the automated suite:

```bash
bash scripts/run-tests.sh
```

Or inspect the live result files:

```bash
LATEST_RESULT="$(ls -1dt artifacts/test-results/* | head -n 1)"
cat "${LATEST_RESULT}/resource-tests.txt"
```

The resource tests demonstrate:

- a normal workload is admitted
- default requests and limits are injected
- an oversized workload is rejected by `LimitRange`
- a quota-exceeding workload is rejected by `ResourceQuota`

## NetworkPolicy Validation

The automated suite deploys one HTTP server and one client pod in each tenant and validates TCP reachability with `wget`.

Manual spot checks:

```bash
kubectl --kubeconfig "$HOME/.kube/config" exec -n team-a network-client -- \
  wget -q -T 5 -O - http://http-echo.team-a.svc.cluster.local

kubectl --kubeconfig "$HOME/.kube/config" exec -n team-a network-client -- \
  wget -q -T 5 -O - http://http-echo.team-b.svc.cluster.local
```

Expected behavior:

- same-namespace HTTP succeeds
- cross-namespace HTTP fails

## Test Evidence

Static validation output:

- `artifacts/test-results/static-validation.log`

Live validation output:

- `artifacts/test-results/<timestamp>/summary.txt`
- `artifacts/test-results/<timestamp>/rbac-tests.txt`
- `artifacts/test-results/<timestamp>/resource-tests.txt`
- `artifacts/test-results/<timestamp>/network-tests.txt`
- `artifacts/test-results/<timestamp>/cluster-state.txt`

## Cleanup

Remove tenants only:

```bash
bash scripts/offboard-team.sh team-a
bash scripts/offboard-team.sh team-b
```

Delete the lab cluster when you are done:

```bash
k3d cluster delete dsaa4040-lab
```

## Troubleshooting

`docker ps` fails inside WSL2

- Start Docker Desktop on Windows.
- Enable WSL integration for the Ubuntu distribution you are using.
- Re-open the WSL shell and rerun `bash scripts/check-environment.sh`.

`k3d` is missing

- Install it with the official script shown above.

`kubectl` points to `https://0.0.0.0:<port>`

- Rerun `bash scripts/bootstrap-cluster.sh`.
- The repository normalizes the cluster server to `https://127.0.0.1:<port>` for WSL2 compatibility.

Live tests are skipped

- `scripts/run-tests.sh` skips live validation if no reachable cluster is detected.
- Use `bash scripts/check-environment.sh` first and confirm that both Docker and the cluster are reachable.

Pod admission warnings appear

- The test workloads in this repository already set `runAsNonRoot`, `seccompProfile`, and dropped Linux capabilities.
- If you add your own workloads, keep the same security context style to stay aligned with Pod Security Admission.

## Deliverables in This Repository

- source code and Kubernetes configuration: `manifests/`, `scripts/`, and supporting docs
- report source: `report.md`
- proposal source: `docs/proposal.md`
- demo script: `docs/demo-script.md`
- reproduction guide: this `README.md`

To submit the report as a PDF, export `report.md` through your preferred Markdown-to-PDF workflow.
