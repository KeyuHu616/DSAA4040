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
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: http-echo
          image: busybox:1.36.1
          command:
            - sh
            - -c
            - |
              mkdir -p /tmp/www
              printf 'hello from __TEAM__\n' > /tmp/www/index.html
              exec httpd -f -p 5678 -h /tmp/www
          ports:
            - containerPort: 5678
              name: http
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
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
