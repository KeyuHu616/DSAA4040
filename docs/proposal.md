# DSAA4040 E3 Project Proposal

## Title

Design and Implementation of a Namespace-Based Soft Multi-Tenant Kubernetes Lab Platform

## Motivation

Student labs often need to share one Kubernetes cluster among multiple teams. Without clear isolation, one team can accidentally modify another team’s resources, read data that should be private, or consume too much CPU and memory. This project proposes a lightweight but correct multi-tenant lab platform that demonstrates the core ideas of cloud platform isolation using native Kubernetes features.

## Objectives

The project aims to build a reproducible Kubernetes lab environment that:

- separates teams by namespace
- implements multiple user roles with RBAC
- enforces resource governance with `ResourceQuota` and `LimitRange`
- enforces network isolation with `NetworkPolicy`
- automates onboarding, kubeconfig generation, and validation
- documents limitations honestly as a soft multi-tenant design

## Proposed Design

Each team will receive its own namespace, beginning with:

- `team-a`
- `team-b`

The system will define three roles:

- platform admin
- tenant developer
- tenant viewer

The platform admin will use the existing cluster-admin kubeconfig. Tenant identities will be simulated with Kubernetes client certificates issued through the CertificateSigningRequest workflow. Developers will be allowed to manage ordinary application resources inside their own namespace, while viewers will have read-only access without Secret visibility.

Each tenant namespace will include:

- namespace labels including `tenant=<team>`
- Pod Security Admission labels
- one `ResourceQuota`
- one `LimitRange`
- a default-deny ingress `NetworkPolicy`
- an allow same-namespace ingress `NetworkPolicy`

## Environment

Primary target:

- WSL2 Ubuntu
- Docker Desktop with WSL integration
- `k3d` running K3s
- Conda environment `cloud`

This environment is lightweight, reproducible, and sufficient for demonstrating real Kubernetes behavior without unnecessary infrastructure complexity.

## Implementation Plan

The repository will contain:

- reusable YAML templates for RBAC, quotas, limits, network policy, and test workloads
- shell scripts for cluster bootstrap, tenant onboarding, tenant offboarding, kubeconfig issuance, and automated tests
- documentation for architecture, onboarding, testing, demo flow, and limitations

Automation will focus on the following scripts:

- `scripts/bootstrap-cluster.sh`
- `scripts/onboard-team.sh`
- `scripts/offboard-team.sh`
- `scripts/issue-user-kubeconfig.sh`
- `scripts/run-tests.sh`

## Evaluation Plan

The project will include both positive and negative tests.

RBAC evaluation:

- developers can manage resources only in their own namespace
- viewers are read-only
- tenant users cannot access Secrets or cross-tenant resources

Resource isolation evaluation:

- ordinary workloads succeed
- default requests and limits are injected
- oversized workloads are rejected
- quota-exceeding workloads are rejected

Network isolation evaluation:

- same-namespace HTTP traffic succeeds
- cross-namespace HTTP traffic fails

All evidence will be written to `artifacts/test-results/` for reproducibility.

## Expected Outcome

The final project will deliver a small but complete platform-style Kubernetes lab that demonstrates:

- tenant separation
- least-privilege RBAC
- namespace-scoped governance
- TCP-based network isolation
- repeatable onboarding and testing

The final submission will include source code and configuration, a technical report, a README with reproduction instructions, and a demo script suitable for a recorded presentation.
