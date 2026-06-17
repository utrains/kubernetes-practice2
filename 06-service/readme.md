## The Service

Since **pods are ephemeral** (can be created and destroyed at any moment), their IP addresses cannot be relied on for communication, that’s where the service resource comes in the picture. Service provides a single **IP address and port** for a set of Pods, it can **load-balance** across them and do **health checks**.

**Note**: This practice can be done on **Killercoda kubernetes playgrounds**

### Expose a pod or a deployment using a service
You can expose a pod or a deployment using a service maifest file or using the `kubectl expose` command

#### Create a service using the manifest

To define a pod and expose it using a service, the **label of the pod** must match the **selector of the service**.

Example: check the `01-service-pod-def.yaml` and `02-service-deployment-def.yaml` files

- Pod and service definition `01-service-pod-def.yaml`. The label defined in the pod spec must match the selector defined in the service. Create the file and paste the following content:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: utrains-pod
  labels:
    name: utrains
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
      - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: utrains-service
spec:
  selector:
    name: utrains
  ports:
  - name: utrains-service-port
    protocol: TCP
    port: 80
    targetPort: 80
```
Apply the file to the cluster and verify with the commands:

```bash
kubectl apply -f 01-service-pod-def.yaml
kubectl get pods
#
# get the services
kubectl get svc
#
# describe the service
kubectl describe service utrains-service
#
# delete the pod and the service
kubectl delete -f 01-service-pod-def.yaml

```
Note: To expose the above pod, you could also run the command. **But it is a best practice to use manifest files instead of running such commands directly.**
```bash
kubectl expose pod utrains-pod --port=80 --target-port=80
```

- Deployment and service definition `02-service-deployment-def.yaml`. The label defined in the pod template must match the selector defined in the service. Create the file with the following content:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  labels:
    app: nginx
spec:
  selector:
      app: nginx
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 80
```
Apply the file to the cluster and verify with the commands:

```bash
kubectl apply -f 02-service-deployment-def.yaml
kubectl get pods
#
# get the services
kubectl get svc
#
# describe the service
kubectl describe service nginx-service
#
# delete the pod and the service
kubectl delete -f 02-service-deployment-def.yaml

```

Note: To expose the above deployment, you could also run the command. **But it is a best practice to use manifest files instead of running such commands directly.**
```bash
kubectl expose deployment nginx-deployment --port=80 --target-port=80
```
### Types of Service

#### **ClusterIP (default)**
- use case: Internal communication between Pods
- Accessible from: **Inside the cluster only**
- Load Balancer: No
- If the service type is not specified, it will be created as a ClusterIP service by default.

Example: file `03-service-clusterIP.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: utrains-service
spec:
  selector:
  type: ClusterIP
    app: utrains
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 80
```

#### **NodePort**
- use case: Exposes a service on a static port on each node (nodeport)
- Accessible from: **Outside the cluster via <Node-IP>:<port>**
- Load Balancer: No
- If the nodeport number is not specified, a random number (30000 - 32767) will be attributed
- If you are working on a cluster in the cloud, remember to open the ports on the nodes security group to be able to access the service from a browser.

Example. file `04-service-nodeport.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: utrains-service
spec:
  type: NodePort
  selector:
    name: utrains
  ports:
      # By default and for convenience, the `targetPort` is set to the same value as the `port` field.
    - port: 80
      targetPort: 80
      # Optional field
      # By default and for convenience, the Kubernetes control plane will allocate a port from a range (default: 30000-32767)
      nodePort: 30007
```

#### **Loadbalancer**
- use case: Exposes service externally using a cloud provider's load balancer
- Accessible from: **Internet (External IP)**
- Load Balancer: yes
- If you are working on a cluster in the cloud, remember to open the ports on the nodes security group to be able to access the service from a browser.

Example: file `05-service-loadbalancer.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: utrains-service
spec:
  type: LoadBalancer
  selector:
    name: utrains
  ports:
      # By default and for convenience, the `targetPort` is set to the same value as the `port` field.
    - port: 80
      targetPort: 80
```

Note: If the ``port`` value is different from ``80`` (default for the LoadBalancer service type), you need open the port in the nodes security group and also specify the port when accessing the service in your browser ``<LoadBalancer>:<port>``

#### **ExternalName**
- use case: Maps a service to an external DNS name
- Accessible from: **Outside the cluster**
- Load Balancer: No
- It’s purely for DNS redirection. No load balancing or port forwarding is involved.

Example: file `06-service-externalname.yaml`. This is just an example, you can make more research on that if necessary.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: utrains-service
  namespace: dev
spec:
  type: ExternalName
  externalName: my.service.example.com
```

## Cleanup

```bash
kubectl delete -f 01-service-pod-def.yaml --ignore-not-found
kubectl delete -f 02-service-deployment-def.yaml --ignore-not-found
kubectl delete -f 03-service-clusterIP.yaml --ignore-not-found
kubectl delete -f 04-service-nodeport.yaml --ignore-not-found
kubectl delete -f 05-service-loadbalancer.yaml --ignore-not-found
kubectl delete -f 06-service-externalname.yaml --ignore-not-found
```

