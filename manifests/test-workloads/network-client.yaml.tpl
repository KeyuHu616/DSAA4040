apiVersion: v1
kind: Pod
metadata:
  name: network-client
  namespace: __TEAM__
  labels:
    app: network-client
spec:
  containers:
    - name: wget
      image: busybox:1.36.1
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 250m
          memory: 256Mi
