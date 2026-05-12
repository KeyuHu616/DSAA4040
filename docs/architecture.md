# Architecture

## Scope

This project implements a namespace-based soft multi-tenant Kubernetes lab platform for teaching and assessment. It is deliberately not presented as hard multi-tenancy. All tenants share one Kubernetes control plane and one worker environment, but the platform applies strong administrative, resource, and network guardrails appropriate for a classroom lab.

## Tenant Model

Each tenant maps to one namespace:

- `team-a`
- `team-b`

Each namespace carries:

- `tenant=<team>`
- `project=dsaa4040`
- Pod Security Admission labels

This model gives each team a clear operational boundary while keeping onboarding simple and reproducible.

## Namespace-Based Isolation

Namespace isolation is the primary isolation primitive in this platform.

Why it fits this project:

- it separates objects cleanly by tenant
- it lets the platform bind RBAC per tenant without cluster-wide privileges
- it provides a natural scope for `ResourceQuota`, `LimitRange`, and `NetworkPolicy`
- it is easy to demonstrate during grading

## Control-Plane Isolation

Control-plane isolation is achieved through Kubernetes-native authentication and authorization:

- users are authenticated with CSR-issued client certificates
- developer identities use `CN=<team>-developer, O=<team>`
- viewer identities use `CN=<team>-viewer, O=<team>`
- generated kubeconfigs default to the tenant namespace

Authorization is tenant-local:

- the developer receives a namespaced custom `Role`
- the developer is bound with a namespaced `RoleBinding`
- the viewer is bound with a namespaced `RoleBinding` to the built-in `view` `ClusterRole`

Important guardrails:

- no tenant user receives a `ClusterRoleBinding`
- no tenant user is placed in `system:masters`
- no tenant user may patch namespaces
- no tenant user may manage RBAC objects, quotas, limit ranges, or network policies

## Data-Plane Isolation

Data-plane isolation in this platform is intentionally soft rather than hardware-strong:

- all workloads run on one Kubernetes node
- all tenants share the same container runtime and kernel
- the CNI enforces namespace-level traffic restrictions

This is appropriate for a teaching lab because it demonstrates multi-tenant design patterns without claiming the guarantees of separate clusters, virtual machines, or confidential compute boundaries.

## Resource Isolation

Each tenant namespace receives one `ResourceQuota` and one `LimitRange`.

`ResourceQuota` controls aggregate namespace consumption:

- pod count
- CPU requests
- memory requests
- CPU limits
- memory limits
- PVC count
- storage requests
- selected object counts

`LimitRange` controls per-container defaults and upper bounds:

- minimum CPU and memory
- maximum CPU and memory
- default requests
- default limits
- PVC minimum and maximum storage

Why both are needed:

- `LimitRange` prevents invalid or oversized single-container specs
- `ResourceQuota` prevents a tenant from exhausting the shared lab node over time
- default requests and limits allow the platform to admit ordinary student workloads without requiring every manifest to be fully resource-tuned

## Network Isolation

Network isolation is namespace-centric and demonstrable with TCP probes.

Each tenant namespace receives:

- a default-deny ingress policy
- an allow same-namespace ingress policy

Result:

- pods inside `team-a` can reach services inside `team-a`
- pods inside `team-b` can reach services inside `team-b`
- cross-namespace service access is blocked by ingress policy

Testing deliberately uses `wget` over HTTP instead of `ping`, because the assignment requires TCP-based proof rather than ICMP.

## Pod Security Admission

Namespaces are labelled with Pod Security Admission settings:

- `enforce=baseline`
- `audit=restricted`
- `warn=restricted`

This balances security with lab compatibility:

- `baseline` blocks the most obviously dangerous pod configurations
- `restricted` in audit and warn mode still surfaces stronger hardening advice during testing and demos
- the repository test workloads also set `runAsNonRoot`, `seccompProfile: RuntimeDefault`, and dropped capabilities to stay close to the restricted baseline

## Automation Flow

The platform automation is intentionally small and direct:

1. `bootstrap-cluster.sh` prepares the recommended `k3d` lab cluster and keeps optional support for direct `k3s` or `minikube`.
2. `onboard-team.sh` applies tenant YAML and issues tenant kubeconfigs.
3. `issue-user-kubeconfig.sh` performs CSR-based certificate issuance.
4. `run-tests.sh` executes RBAC, quota, limit, and network tests and stores evidence.
5. `offboard-team.sh` removes a tenant namespace and local credentials.

## Limitations

This lab platform has important limits and they should be stated clearly:

- it is a single-node environment, so node failure takes down both control plane and workloads
- tenants still share the same kernel and host
- namespace isolation does not equal hard tenant isolation
- storage uses single-node local semantics unless the operator swaps in a multi-node CSI
- this design prioritizes reproducibility and grading evidence over production-scale multi-cluster isolation
