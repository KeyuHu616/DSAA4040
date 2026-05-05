apiVersion: v1
kind: Namespace
metadata:
  name: __TEAM__
  labels:
    app.kubernetes.io/name: dsaa4040-multitenant-lab
    app.kubernetes.io/part-of: dsaa4040-e3
    project: dsaa4040
    tenant: __TEAM__
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
