apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-echo
  namespace: __TEAM__
  labels:
    app: http-echo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: http-echo
  template:
    metadata:
      labels:
        app: http-echo
    spec:
      containers:
        - name: http-echo
          image: hashicorp/http-echo:0.2.3
          args:
            - -text=hello from __TEAM__
          ports:
            - containerPort: 5678
              name: http
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 250m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: http-echo
  namespace: __TEAM__
spec:
  selector:
    app: http-echo
  ports:
    - name: http
      port: 80
      targetPort: 5678
