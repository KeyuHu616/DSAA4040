apiVersion: v1
kind: Pod
metadata:
  name: quota-exceeded-workload
  namespace: __TEAM__
  labels:
    app: quota-exceeded-workload
spec:
  containers:
    - name: worker-a
      image: busybox:1.36.1
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: "1"
          memory: 1Gi
        limits:
          cpu: "1"
          memory: 1Gi
    - name: worker-b
      image: busybox:1.36.1
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: "1"
          memory: 1Gi
        limits:
          cpu: "1"
          memory: 1Gi
