apiVersion: v1
kind: Pod
metadata:
  name: oversized-workload
  namespace: __TEAM__
  labels:
    app: oversized-workload
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: busybox:1.36.1
      command: ["sh", "-c", "sleep 3600"]
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
      resources:
        requests:
          cpu: 1500m
          memory: 2Gi
        limits:
          cpu: 1500m
          memory: 2Gi
