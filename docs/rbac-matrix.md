# RBAC Matrix

## Identity Model

Tenant users are authenticated with CSR-issued client certificates:

- developer: `CN=<team>-developer, O=<team>`
- viewer: `CN=<team>-viewer, O=<team>`

Authorization is namespace-scoped:

- developers are bound to a custom namespaced `Role`
- viewers are bound to the built-in `view` `ClusterRole` through a namespaced `RoleBinding`

No tenant user receives a `ClusterRoleBinding`.

## Permission Matrix

| Resource or Action | Platform Admin | Tenant Developer | Tenant Viewer |
| --- | --- | --- | --- |
| Bootstrap cluster and administer the whole cluster | Yes | No | No |
| Create or delete namespaces | Yes | No | No |
| Patch namespaces | Yes | No | No |
| Approve CSRs | Yes | No | No |
| Manage deployments in own namespace | Yes | Yes | No |
| Manage pods in own namespace | Yes | Yes | No |
| Get pod logs in own namespace | Yes | Yes | Yes |
| Manage services in own namespace | Yes | Yes | No |
| Manage configmaps in own namespace | Yes | Yes | No |
| Manage PVCs in own namespace | Yes | Yes | No |
| Manage jobs and cronjobs in own namespace | Yes | Yes | No |
| Read events in own namespace | Yes | Yes | Yes |
| Access another tenant namespace | Yes | No | No |
| Read Secrets in own namespace | Yes | No | No |
| Manage quotas, limit ranges, or network policies | Yes | No | No |
| Manage roles or rolebindings | Yes | No | No |
| Use ClusterRoleBinding | Yes | No | No |

## Required Acceptance Commands

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

Viewer A allowed:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get pods -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i list services -n team-a
```

Viewer A denied:

```bash
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i create deployments -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i delete pods -n team-a
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get pods -n team-b
kubectl --kubeconfig artifacts/kubeconfigs/team-a-viewer.kubeconfig auth can-i get secrets -n team-a
```
