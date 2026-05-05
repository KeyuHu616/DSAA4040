# RBAC Matrix

## Identity Model

The platform uses CSR-issued client certificates for simulated users:

- developer: `CN=<team>-developer, O=<team>`
- viewer: `CN=<team>-viewer, O=<team>`

RBAC bindings are user-specific inside each namespace:

- developer user bound to custom namespaced `Role`
- viewer user bound to built-in `view` `ClusterRole` through a namespaced `RoleBinding`

This avoids cluster-wide tenant bindings and keeps permissions explicit.

## Permission Matrix

| Resource or Action | Platform Admin | Tenant Developer | Tenant Viewer |
| --- | --- | --- | --- |
| Cluster bootstrap and cluster-wide admin | Yes | No | No |
| Create namespaces | Yes | No | No |
| Patch or update namespaces | Yes | No | No |
| Create or approve CSRs | Yes | No | No |
| Create deployments in own namespace | Yes | Yes | No |
| Manage pods in own namespace | Yes | Yes | No |
| Get pod logs in own namespace | Yes | Yes | Yes |
| Manage services in own namespace | Yes | Yes | No |
| Manage configmaps in own namespace | Yes | Yes | No |
| Manage PVCs in own namespace | Yes | Yes | No |
| Manage jobs and cronjobs in own namespace | Yes | Yes | No |
| Read events in own namespace | Yes | Yes | Yes |
| Access other tenant namespaces | Yes | No | No |
| Get secrets in own namespace | Yes | No | No |
| Manage quotas, limit ranges, or network policies | Yes | No | No |
| Manage roles or rolebindings | Yes | No | No |
| Use ClusterRoleBinding | Yes | No | No |

## Developer Role Rules

The custom developer `Role` permits only normal application management inside the tenant namespace:

- `pods`
- `pods/log`
- `services`
- `configmaps`
- `persistentvolumeclaims`
- `deployments`
- `replicasets`
- `jobs`
- `cronjobs`
- `events`

The role intentionally does not include:

- `secrets`
- `namespaces`
- `resourcequotas`
- `limitranges`
- `networkpolicies`
- `roles`
- `rolebindings`
- `clusterroles`
- `clusterrolebindings`

## Viewer Binding

The viewer uses the Kubernetes built-in `view` `ClusterRole`, but only through a namespaced `RoleBinding`.

Why this is safe for the assignment:

- it is read-only
- it does not grant secret reads
- it does not grant mutation
- it does not create cluster-wide privilege because the binding is namespace-scoped

## Required Acceptance Checks

Developer A must be allowed:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods/log -n team-a
```

Developer A must be denied:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get pods -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i create deployments -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i update resourcequotas -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i update networkpolicies -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i create rolebindings -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i patch namespace/team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-developer.kubeconfig auth can-i get secrets -n team-a
```

Viewer A must be allowed:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get pods -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i list services -n team-a
```

Viewer A must be denied:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i delete pods -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get pods -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get secrets -n team-a
```
