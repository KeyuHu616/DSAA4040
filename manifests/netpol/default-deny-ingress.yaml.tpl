apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: __TEAM__
spec:
  podSelector: {}
  policyTypes:
    - Ingress
