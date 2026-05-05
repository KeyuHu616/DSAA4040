# High Availability Discussion

## Why the Main Implementation Uses a Single Node

The project target is a reproducible teaching lab, not a production platform. A single-node environment is the right baseline because it keeps the core learning goals visible:

- namespace-based tenant isolation
- RBAC for developers and viewers
- resource governance with quota and limits
- network isolation with enforced `NetworkPolicy`
- automated onboarding and evidence generation

This choice reduces moving parts and makes grading easier:

- one machine is enough
- bootstrap is faster
- failures are easier to diagnose
- storage behavior is straightforward

For DSAA 4040 E3, this creates a stable environment for demonstrating multi-tenant Kubernetes design without hiding the logic behind larger infrastructure.

## What Single-Node Does Not Provide

A single-node lab has important limits:

- no control-plane redundancy
- no workload redundancy if the node fails
- local storage depends on one host
- all tenants still share one kernel and runtime host

Because of that, the platform must be described as soft multi-tenancy, not hard multi-tenancy.

## What Would Change for Multi-Node or HA

To evolve this project toward a more resilient deployment, the following changes would be required.

### Control Plane

- move from a single-node server to a multi-server control plane
- for K3s, use embedded etcd HA or an external datastore
- provide stable API server access through a fixed endpoint or load balancer
- plan certificate and kubeconfig distribution more carefully

### Worker Capacity and Scheduling

- add worker nodes so workload capacity is not tied to one host
- consider node labels, taints, and affinity if tenant placement becomes important
- re-test quotas and scheduling behavior under multi-node conditions

### Storage

- replace single-node local storage assumptions with a real CSI suitable for multiple nodes
- ensure PVC semantics remain stable when pods move between nodes
- add backup and recovery procedures for stateful workloads

### Networking

- keep a CNI that enforces `NetworkPolicy` consistently across nodes
- verify service routing and cross-node traffic still obey tenant isolation
- if platform-wide default policies are needed, consider Calico global policy as a future extension

### Operations

- add monitoring, alerting, and log collection
- manage upgrades more carefully
- automate certificate rotation rather than just issuance
- test disaster recovery, not only normal functionality

## Why Those Changes Are Outside the Main Submission

Those improvements are useful, but they are not necessary to prove the assignment requirements. Pushing them into the main implementation would add risk:

- more infrastructure complexity
- more failure modes
- less reproducibility for a grader on a single machine

The submitted design therefore uses a single-node cluster as the primary path and treats HA or multi-node deployment as an extension path, not a dependency for core marks.
