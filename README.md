# DSAA4040 E3 Kubernetes Multi-Tenant Lab Platform

This repository implements the DSAA4040 E3 namespace-based soft multi-tenant Kubernetes lab platform.

The core platform remains unchanged:

- RBAC for `developer` and `viewer`
- CSR-based users and generated kubeconfigs
- `ResourceQuota`
- `LimitRange`
- `NetworkPolicy`
- Pod Security labels
- onboarding and offboarding scripts
- automated tests and saved artifacts

The required tenants are:

- `team-a`
- `team-b`

## Recommended Live Validation Environment

The recommended live environment is:

- Windows
- WSL2 Ubuntu
- Docker Desktop with WSL integration enabled
- Conda environment `cloud`
- k3d cluster `dsaa4040-lab`

Create or update the Conda environment:

```bash
conda env create -f environment.yml || conda env update -f environment.yml --prune
conda activate cloud
chmod +x scripts/*.sh
```

If `k3d` is missing, install it once:

```bash
command -v k3d >/dev/null 2>&1 || curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

## Live Deployment Path

From a fresh checkout in WSL2:

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
ls -1dt artifacts/test-results/*
```

What this should do:

- confirm Docker access
- create or connect to the k3d cluster
- point `kubectl` and the repo scripts at `$HOME/.kube/config`
- onboard both required tenants
- run the live RBAC, resource-governance, and TCP-based network tests
- save timestamped evidence under `artifacts/test-results/`

Why the explicit server rewrite matters:

- some WSL2/k3d kubeconfigs can expose the API server as `https://0.0.0.0:6550`
- this repository normalizes that to `https://127.0.0.1:6550` for stable `kubectl` access inside WSL2

## Static Validation Path

On a no-sudo Linux server used only for coding and static checks:

```bash
conda activate cloud
chmod +x scripts/*.sh
bash scripts/check-environment.sh
bash scripts/static-validate.sh
bash scripts/run-tests.sh
```

Expected behavior:

- static validation completes
- `bash scripts/run-tests.sh` falls back cleanly when no real cluster is reachable
- it prints:

```text
Static validation completed; live Kubernetes validation is pending on WSL2 or another Docker/Kubernetes-enabled machine.
```

## Optional GUI Dashboard

This project includes an optional local Streamlit dashboard for presentation demos.

Warning:

- this is a local demo dashboard only
- it is not a production portal
- it should be bound only to `127.0.0.1`

If your existing Conda environment was created before `streamlit` was added, update it:

```bash
conda env update -f environment.yml --prune
```

If you prefer a targeted install instead:

```bash
pip install streamlit
```

Start the GUI:

```bash
conda activate cloud
streamlit run gui/app.py --server.address 127.0.0.1 --server.port 8501
```

Open:

```text
http://127.0.0.1:8501
```

The GUI can show:

- cluster overview with `kubectl get nodes -o wide` and `kubectl get ns`
- whether `team-a` and `team-b` exist
- per-tenant quota, limit range, network policy, and rolebinding summaries
- generated kubeconfig filenames and user names
- buttons for `check-environment`, `bootstrap-cluster`, `onboard-team.sh team-a`, `onboard-team.sh team-b`, and `run-tests.sh`
- latest timestamped test-results files
- a demo checklist

The GUI intentionally does not:

- expose private key contents
- bind to `0.0.0.0` by default
- offer cluster deletion buttons
- offer offboarding buttons by default

## Test Artifacts

Static validation log:

- `artifacts/test-results/static-validation.log`

Live test runs:

- `artifacts/test-results/<timestamp>/summary.txt`
- `artifacts/test-results/<timestamp>/rbac-tests.txt`
- `artifacts/test-results/<timestamp>/resource-tests.txt`
- `artifacts/test-results/<timestamp>/network-tests.txt`
- `artifacts/test-results/<timestamp>/cluster-state.txt`

Rendered manifests for static checks:

- `artifacts/rendered/team-a/...`
- `artifacts/rendered/team-b/...`

## Related Docs

- [Onboarding Guide](docs/onboarding-guide.md)
- [Testing Guide](docs/testing-guide.md)
- [Demo Script](docs/demo-script.md)
- [Architecture](docs/architecture.md)
- [RBAC Matrix](docs/rbac-matrix.md)
- [HA Discussion](docs/ha-discussion.md)
