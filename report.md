# DSAA4040 E3 Technical Report

## Design and Implementation of a Namespace-Based Soft Multi-Tenant Kubernetes Lab Platform

**Course:** DSAA 4040 Cloud Computing & Big Data Systems  
**Track:** Engineering-Oriented Project  
**Project:** E3. Multi-Tenant Kubernetes Lab Platform with RBAC and Resource Isolation  
**Team Members:** _Fill in before submission_  
**Submission Date:** _Fill in before submission_

## Problem Statement

Teaching labs and student project environments often need to share one Kubernetes cluster among multiple teams. Without isolation, one team can accidentally read another team’s resources, consume too much CPU or memory, or interfere with application traffic. The goal of this project is to implement a small but technically correct Kubernetes lab platform that demonstrates multi-tenancy, least-privilege access control, resource governance, and network isolation in a form that can be reproduced easily by a grader.

This project targets the DSAA 4040 E3 requirements. The platform must define multiple roles, separate tenants into namespaces, demonstrate different permissions, apply resource isolation, and provide documentation and automation for onboarding and validation. The design deliberately uses **soft multi-tenancy** rather than hard isolation. All tenants share one control plane and one worker environment, but they are constrained by Kubernetes-native policy objects and namespace boundaries.

## System Design

### Design Goals

The design was guided by four goals:

1. **Correctness:** access control and isolation must be enforced by Kubernetes rather than by naming convention or UI logic.
2. **Reproducibility:** a grader should be able to follow one README workflow and reproduce the environment.
3. **Demonstrability:** every major claim should map to a concrete command or automated test.
4. **Simplicity:** the project should stay focused on the course topic instead of adding unnecessary platform layers.

### Tenant Model

The platform uses one namespace per team:

- `team-a`
- `team-b`

Each namespace is labeled with:

- `tenant=<team>`
- project metadata labels
- Pod Security Admission labels

Namespace isolation is the primary administrative boundary. This is the simplest and most defensible pattern for a course-scale multi-tenant platform because Kubernetes RBAC, `ResourceQuota`, `LimitRange`, and `NetworkPolicy` are all naturally namespaced.

### Role Model

The platform implements three roles:

1. **Platform Admin**
   The platform administrator uses the existing cluster-admin kubeconfig and performs bootstrap, onboarding, certificate approval, and validation tasks.

2. **Tenant Developer**
   A developer can manage normal application resources only inside the team namespace. The role allows common resources such as Pods, Deployments, ReplicaSets, Services, ConfigMaps, Jobs, CronJobs, Events, Pod logs, and PVCs. The role does **not** permit access to Secrets, namespaces, RBAC objects, quotas, limit ranges, or network policies.

3. **Tenant Viewer**
   A viewer has read-only access inside the team namespace and is explicitly denied mutation privileges and Secret reads.

This structure satisfies the basic E3 requirement to define multiple roles while also reflecting a realistic platform-admin versus tenant-user separation.

### Identity and Authentication

Simulated users are implemented with Kubernetes client certificates issued through the CertificateSigningRequest workflow. For each tenant, the repository generates:

- `<team>-developer`
- `<team>-viewer`

The certificate subject format is:

- `CN=<team>-developer, O=<team>`
- `CN=<team>-viewer, O=<team>`

The generated kubeconfigs default to the user namespace so that tenant commands run in the correct namespace unless the user explicitly overrides it.

### Isolation Model

The platform combines four complementary isolation mechanisms.

**Administrative isolation**

- namespaces separate tenant objects
- tenant RBAC is namespace-scoped
- tenant users receive no `ClusterRoleBinding`
- tenant users are never added to `system:masters`

**Resource isolation**

- each tenant gets one `ResourceQuota`
- each tenant gets one `LimitRange`
- defaults are injected for workloads that omit requests and limits
- oversized or quota-exceeding workloads are rejected by the API server

**Network isolation**

- each tenant gets a default-deny ingress `NetworkPolicy`
- each tenant gets an allow-same-namespace ingress `NetworkPolicy`
- same-namespace TCP access is allowed
- cross-namespace TCP access is denied

**Pod security hardening**

- namespaces use Pod Security Admission labels
- test workloads set `runAsNonRoot`
- test workloads use `seccompProfile: RuntimeDefault`
- test workloads drop Linux capabilities and disable privilege escalation

### Runtime Choice

The main validated environment is `k3d` on WSL2 Ubuntu with Docker Desktop integration. This choice keeps setup light while still running real Kubernetes control-plane logic. `k3d` runs K3s inside Docker containers, which is appropriate for a teaching lab and much easier for a grader to reproduce than a heavier multi-node deployment. Script-level support for direct `k3s` or `minikube` is preserved, but the submission focuses on the `k3d` path to keep the demonstration stable and consistent.

## Implementation

### Repository Structure

The final repository is intentionally focused on submission-critical artifacts:

- `manifests/` for RBAC, quotas, limits, network policies, Pod Security labels, and test workloads
- `scripts/` for bootstrap, onboarding, offboarding, kubeconfig issuance, and test automation
- `docs/` for architecture, RBAC matrix, onboarding, testing, demo script, HA discussion, and proposal
- `artifacts/` for generated kubeconfigs, rendered manifests, and test results
- `README.md` for reproduction instructions
- `report.md` for the technical report source

Optional UI layers that were not necessary for grading were removed from the final submission path to reduce ambiguity.

### Onboarding Automation

`scripts/onboard-team.sh` is idempotent and accepts a tenant name such as:

```bash
bash scripts/onboard-team.sh team-a
```

For each tenant, it:

1. applies the namespace and Pod Security labels
2. applies the developer `Role`
3. applies the developer and viewer `RoleBinding`
4. applies the `ResourceQuota`
5. applies the `LimitRange`
6. applies the `NetworkPolicy` objects
7. issues fresh developer and viewer kubeconfigs

This script is intentionally small and declarative. YAML templates live under `manifests/`, and the onboarding script only performs parameter substitution and `kubectl apply`.

### Kubeconfig Issuance

`scripts/issue-user-kubeconfig.sh` generates a private key, creates a CSR, submits it to Kubernetes, approves it through the admin kubeconfig, retrieves the signed certificate, and writes a namespaced kubeconfig to `artifacts/kubeconfigs/`.

This approach is preferable to inventing fake users in documentation because it uses Kubernetes’ real authentication path. It also makes the RBAC tests meaningful: the access checks are performed by actual tenant identities rather than by impersonation shortcuts in the admin context.

### Resource Governance

Each namespace receives:

- one `ResourceQuota`
- one `LimitRange`

The quota constrains aggregate namespace usage such as total Pods, CPU requests, memory requests, limits, PVC count, and storage requests. The limit range constrains per-container minima, maxima, and defaults. Together, they protect the shared lab node from accidental resource abuse.

### Network Policies

The platform uses a minimal but effective namespace isolation pattern:

- `default-deny-ingress`
- `allow-same-namespace-ingress`

This is easy to explain during grading and easy to verify with TCP-based checks. It also matches the project requirement to show that teams can communicate within their own namespace but not across namespaces.

### Static and Live Validation

The repository distinguishes clearly between:

- **static validation**, which checks repository structure, shell syntax, template rendering, YAML parsing, and workload hardening
- **live validation**, which requires a reachable Kubernetes cluster and runs RBAC, quota, limit, and network tests

This distinction prevents overclaiming. If the cluster is unavailable, the repository still provides useful static validation without pretending that cluster-enforced behavior was tested.

## Deployment / Demo

The recommended live demo path is:

```bash
conda activate cloud
chmod +x scripts/*.sh
bash scripts/check-environment.sh
bash scripts/bootstrap-cluster.sh
bash scripts/onboard-team.sh team-a
bash scripts/onboard-team.sh team-b
bash scripts/run-tests.sh
```

This sequence demonstrates the full platform lifecycle:

1. confirm environment readiness
2. bootstrap the cluster
3. onboard the required tenants
4. generate tenant kubeconfigs
5. execute automated validation
6. collect timestamped evidence under `artifacts/test-results/`

The accompanying `docs/demo-script.md` gives a concise narrative for a live or recorded demonstration. The demo intentionally stays close to the CLI workflow so that the grader sees the platform controls directly rather than through an additional presentation layer.

## Evaluation and Testing

The automated tests were designed to map directly to the E3 grading expectations.

### RBAC Tests

The suite uses `kubectl auth can-i` with tenant kubeconfigs. It verifies that:

- Developer A can create deployments and read pods and pod logs inside `team-a`
- Developer A cannot access `team-b`
- Developer A cannot update quotas or network policies
- Developer A cannot create rolebindings
- Developer A cannot patch namespaces
- Developer A cannot read Secrets
- Viewer A can read in `team-a`
- Viewer A cannot mutate resources
- Viewer A cannot read Secrets

The test suite also verifies that the generated kubeconfigs default to the correct namespace and reference the expected user names.

### Resource Governance Tests

The suite applies four kinds of workloads:

1. a normal workload that should succeed
2. a workload without explicit requests and limits, to show default injection
3. an oversized workload that should fail the `LimitRange`
4. a quota-exceeding workload that should fail the `ResourceQuota`

These checks demonstrate both positive and negative behavior, which is important for completeness and robustness.

### Network Isolation Tests

The suite deploys:

- an HTTP server in `team-a`
- an HTTP server in `team-b`
- a client pod in each tenant

The checks then use `wget` over HTTP to verify:

- `team-a` can reach `team-a`
- `team-b` can reach `team-b`
- `team-a` cannot reach `team-b`
- `team-b` cannot reach `team-a`

TCP-based validation was chosen deliberately because the project requirement explicitly calls for TCP tooling rather than ICMP or `ping`.

### Evidence

The automated suite writes:

- `summary.txt`
- `rbac-tests.txt`
- `resource-tests.txt`
- `network-tests.txt`
- `cluster-state.txt`

This evidence-oriented approach improves grading confidence because claims in the report can be traced to generated artifacts rather than screenshots alone.

## Limitations and Future Work

This submission is intentionally a **soft multi-tenant lab platform**, not a production-grade hard multi-tenant system.

Current limitations:

- one cluster is shared by all tenants
- one node failure affects the whole lab
- tenants still share the same host kernel and container runtime
- storage semantics remain single-node unless replaced with a more advanced CSI setup
- identity is simulated with local certificate issuance rather than an enterprise identity provider

Future improvements:

1. move to multi-server or HA K3s with embedded etcd or an external datastore
2. add external identity integration such as OIDC
3. expand policy coverage with egress controls or more granular namespace templates
4. add richer storage and backup workflows for stateful workloads
5. integrate monitoring and audit pipelines for a more operations-oriented platform

The important point is that these are extensions, not missing fundamentals. The current submission already covers the core engineering focus of E3: multi-tenancy, isolation, RBAC, resource governance, and reproducible platform automation.

## References

1. Kubernetes Documentation. “Using RBAC Authorization.” https://kubernetes.io/docs/reference/access-authn-authz/rbac/
2. Kubernetes Documentation. “Certificates and Certificate Signing Requests.” https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/
3. Kubernetes Documentation. “Resource Quotas.” https://kubernetes.io/docs/concepts/policy/resource-quotas/
4. Kubernetes Documentation. “Limit Ranges.” https://kubernetes.io/docs/concepts/policy/limit-range/
5. Kubernetes Documentation. “Network Policies.” https://kubernetes.io/docs/concepts/services-networking/network-policies/
6. Kubernetes Documentation. “Pod Security Admission.” https://kubernetes.io/docs/concepts/security/pod-security-admission/
7. Kubernetes Documentation. “Declare Network Policy.” https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/
8. K3s Documentation. “Networking.” https://docs.k3s.io/networking
9. K3s Documentation. “Networking Services.” https://docs.k3s.io/networking/networking-services
10. k3d Documentation. “Overview.” https://k3d.io/

## Appendix A: AI Use Disclosure

AI assistance was used for brainstorming repository cleanup, generating draft documentation structure, and reviewing implementation consistency. All code, manifests, scripts, and report content were manually checked against the project requirements and repository behavior before submission.
