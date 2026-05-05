# AGENTS.md

## Project Goal

This repository implements the DSAA 4040 Cloud Computing & Big Data Systems E3 project:

**Design and Implementation of a Namespace-Based Soft Multi-Tenant Kubernetes Lab Platform with RBAC, Resource Isolation, Network Isolation, and Automated Tenant Onboarding.**

The implementation must follow `docs/proposal.md` strictly.

The final project should be suitable for full-mark grading. Prioritize correctness, reproducibility, clear documentation, and demonstrable security isolation over unnecessary features.

## Baseline Environment

Use a single-node Kubernetes lab environment.

Primary target:
- K3s or k3d on Linux / WSL2 Ubuntu.

Acceptable local alternative:
- Minikube with Calico enabled.

NetworkPolicy must be actually enforced. Do not rely on a Kubernetes environment where NetworkPolicy objects exist but are not enforced by the CNI.

## Required Repository Structure

Create and maintain the following structure:

```text
.
├── README.md
├── AGENTS.md
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
│   ├── onboard-team.sh
│   ├── offboard-team.sh
│   ├── issue-user-kubeconfig.sh
│   └── run-tests.sh
└── artifacts/
    ├── kubeconfigs/
    └── test-results/
````

## Implementation Requirements

Implement at least two tenants:

* `team-a`
* `team-b`

Each tenant must have:

* A dedicated namespace.
* Namespace labels:

  * `tenant=<team-name>`
  * Pod Security Admission labels.
* One ResourceQuota.
* One LimitRange.
* NetworkPolicies:

  * default deny ingress.
  * allow same-namespace ingress.
* RBAC RoleBindings for:

  * developer.
  * viewer.
* Generated kubeconfigs for simulated users.

## Role Model

Implement three roles:

### Platform Admin

The admin uses the existing cluster-admin kubeconfig. Do not generate a fake cluster-admin user for tenants.

### Tenant Developer

Developer users may manage normal application resources only inside their own namespace.

Developer should be able to work with:

* pods
* deployments
* replicasets
* services
* configmaps
* jobs
* cronjobs
* events
* pods/log
* persistentvolumeclaims, if included in the demo

Developer must NOT be able to manage:

* namespaces
* resourcequotas
* limitranges
* networkpolicies
* roles
* rolebindings
* clusterroles
* clusterrolebindings
* secrets
* other tenants' resources

Do not bind tenant developers to the built-in `admin` role.

### Tenant Viewer

Viewer users may read resources only inside their own namespace.

Viewer must not create, update, patch, or delete resources.

Viewer must not read Secrets.

It is acceptable to bind viewers to the built-in `view` ClusterRole via a namespaced RoleBinding.

## Security Constraints

Never give tenant users ClusterRoleBinding.

Never put tenant users into `system:masters`.

Never give tenant users namespace patch/update permission.

Do not use `ping` as the proof of NetworkPolicy success. NetworkPolicy validation must use TCP tools such as `curl`, `wget`, or `nc`.

Do not create multiple LimitRange objects with conflicting default values in the same tenant namespace.

Do not describe this platform as hard multi-tenancy. It is a soft multi-tenant teaching lab platform.


## Automation Requirements


`scripts/onboard-team.sh` must support:

```bash
./scripts/onboard-team.sh team-a
./scripts/onboard-team.sh team-b
```

The script should be idempotent.

For each team, it should:

1. Create namespace if absent.
2. Add required labels.
3. Apply Pod Security labels.
4. Apply ResourceQuota.
5. Apply LimitRange.
6. Apply NetworkPolicies.
7. Apply Developer Role and RoleBinding.
8. Apply Viewer RoleBinding.
9. Generate or refresh kubeconfigs for:

   * `<team>-developer`
   * `<team>-viewer`
10. Save kubeconfigs under:

* `artifacts/kubeconfigs/<team>-developer.kubeconfig`
* `artifacts/kubeconfigs/<team>-viewer.kubeconfig`

`scripts/offboard-team.sh` must remove one tenant safely:

```bash
./scripts/offboard-team.sh team-a
```

It should delete the namespace and clean related generated local artifacts.

## Certificate and Kubeconfig Requirements

Use Kubernetes CertificateSigningRequest workflow for simulated users where feasible.

The user naming convention should be:

```text
CN=<team>-developer, O=<team>
CN=<team>-viewer, O=<team>
```

Generated kubeconfigs must default to the user's namespace.

## Testing Requirements

`scripts/run-tests.sh` must run automated tests and write outputs to:

```text
artifacts/test-results/
```

The tests must include positive and negative cases.

### RBAC Tests

Use `kubectl auth can-i`.

Required checks:

Developer A can:

```bash
create deployments -n team-a
get pods -n team-a
get pods/log -n team-a
```

Developer A cannot:

```bash
get pods -n team-b
create deployments -n team-b
update resourcequotas -n team-a
update networkpolicies -n team-a
create rolebindings -n team-a
patch namespace team-a
get secrets -n team-a
```

Viewer A can:

```bash
get pods -n team-a
list services -n team-a
```

Viewer A cannot:

```bash
create deployments -n team-a
delete pods -n team-a
get pods -n team-b
get secrets -n team-a
```

### ResourceQuota and LimitRange Tests

Create a normal workload that succeeds.

Create a workload without explicit requests/limits and verify default values are injected.

Create an oversized workload that exceeds LimitRange and confirm it is rejected.

Create workloads that exceed namespace ResourceQuota and confirm they are rejected.

### NetworkPolicy Tests

Deploy a simple HTTP server in `team-a`.

Deploy a simple HTTP server in `team-b`.

Verify:

* Pod in `team-a` can curl service in `team-a`.
* Pod in `team-b` can curl service in `team-b`.
* Pod in `team-a` cannot curl service in `team-b`.
* Pod in `team-b` cannot curl service in `team-a`.

Use TCP-based tests only.

## Documentation Requirements

README.md must include:

1. Environment prerequisites.
2. Cluster bootstrap commands.
3. Tenant onboarding commands.
4. Generated kubeconfig usage.
5. RBAC testing commands.
6. Quota testing commands.
7. NetworkPolicy testing commands.
8. Cleanup commands.
9. Troubleshooting section.

`docs/architecture.md` must explain:

* soft multi-tenancy.
* namespace-based isolation.
* control-plane isolation.
* data-plane isolation.
* resource isolation.
* network isolation.
* limitations.

`docs/rbac-matrix.md` must contain a clear permission matrix.

`docs/demo-script.md` must provide a step-by-step demo video script.

`docs/ha-discussion.md` must explain why the project uses a single-node lab environment and what changes would be required for multi-node or HA deployment.

## Acceptance Criteria

The project is complete only if:

1. A fresh user can follow README.md and reproduce the platform.
2. `team-a` and `team-b` are created automatically.
3. Developer and viewer kubeconfigs are generated.
4. Developer A cannot access Team B resources.
5. Viewer A cannot mutate resources.
6. ResourceQuota and LimitRange behavior is demonstrated.
7. Cross-namespace TCP traffic is blocked by NetworkPolicy.
8. Same-namespace TCP traffic works.
9. All test results are saved under `artifacts/test-results/`.
10. The report documents design choices, test results, limitations, and high-availability discussion.

## Coding Style

Prefer Bash scripts unless Python is clearly better.

Scripts must:

* use `set -euo pipefail`.
* print clear progress messages.
* be idempotent where possible.
* fail loudly when required tools are missing.
* avoid hard-coded absolute paths.
* work from the repository root.

YAML files must be readable, named clearly, and organized by function.

Do not add unnecessary web dashboards or frontend code unless all core requirements are already complete.