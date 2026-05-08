# GUI Backend Guide

## Scope

This repository now includes a local-only FastAPI backend and React frontend for demo and management use.

Important constraints:

- the web layer runs on localhost only
- it does not replace Kubernetes RBAC, ResourceQuota, LimitRange, or NetworkPolicy
- it only wraps existing scripts and read-only `kubectl` queries
- private keys are never exposed through the web API

## Local Start Commands

Prepare Python dependencies:

```bash
conda env update -f environment.yml --prune
conda activate cloud
```

Prepare frontend dependencies:

```bash
cd frontend
npm install
cd ..
```

Start backend only:

```bash
make backend-dev
```

Start frontend only:

```bash
make frontend-dev
```

Start both locally:

```bash
make dev
```

## Local Addresses

- frontend: `http://127.0.0.1:5173`
- backend OpenAPI docs: `http://127.0.0.1:8000/docs`

## Safety Model

The backend enforces these local safety controls:

- fixed script whitelist
- fixed read-only `kubectl get` whitelist
- tenant name regex validation
- explicit offboard confirmation
- file-backed task and audit logs under `artifacts/gui-runs/`
- serialized execution for bootstrap, onboarding, offboarding, and test runs

## Validation

Run backend tests:

```bash
make backend-tests
```

Run frontend build validation:

```bash
make frontend-build
```

Run the combined local web validation path:

```bash
make web-validate
```
