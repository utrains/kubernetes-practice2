**Note**: This practice can be done on **Killercoda kubernetes playgrounds**

## The Pod in Kubernetes
### Definition
A **Pod** is the smallest and simplest Kubernetes object (Smallest or atomic unit in K8s). It can contain one or more containers. Each pod has its own IP address for communication. Containers in the pod share the pod IP address and namespace.

**Pods are ephemeral ie they can die and be replaced easily.**

### Running a Pod
To run a pod in the cluster, you can use either a manifest or the use `kubectl run` command with parameters.

#### Using the manifest 

1- Create a simple pod running the httpd image.
- Create a yaml file called `01-simple-pod.yaml`. Its content should look like the following
```yaml
apiVersion: v1
kind: Pod
metadata:
 name: utrains
spec:
 containers:
   - name: utrains-app
     image: httpd
```

- Create the pod in the cluster with the command:
```bash
kubectl create -f 01-simple-pod.yaml
```
- List and describe pods
```bash
kubectl get pods 
kubectl get pods -A 
kubectl get pods -o wide
kubectl describe pod utrains
```
#### Using the command
Create a pod called `app1` running the nginx image
```bash 
kubectl run app1 --image=nginx
kubectl get pod
kubectl get pod -o wide 
```
### Practice with pods
1. Create pod with a wrong image name then edit it to modify the image name
```bash 
kubectl run app2 --image nginxjdf
kubectl get pods
kubectl get pod -o wide
# you should get an error ErrImagePull or ImagePullBackOff
kubectl describe pod app2
kubectl edit pod app2
# modify the image name to nginx, save and exit the edition page
kubectl get pods
# The pod should now be Running
```
2. Get the logs of a pod (this is useful for troubleshooting when a pod has issues)
```bash 
kubectl logs app1
kubectl logs app2
```

3. Delete pods
```bash 
kubectl delete pod app1
kubectl delete pod app2
kubectl delete pod utrains
```

4. Generate definition file for running a pod with nginx and write it into a file called `pod.yaml`
```bash
kubectl run nginx2 --image=nginx --dry-run=client -o yaml > pod.yaml
cat pod.yaml
```

5. create a pod in a specific namespace (dev). Verify the content of the `02-pod-namespace.yaml` file. 

Here, the namespace must first be created.

```bash
kubectl create namespace dev
```
The content of the manifest
```yaml
apiVersion: v1
kind: Pod
metadata:
 name: utrains
 namespace: dev
 labels:
  app: utrains
spec:
 containers:
   - name: utrains-app
     image: httpd
```

deploy and verify the pod
```bash
kubectl create -f pod-namespace.yaml
kubectl get pods 
kubectl get pods -n dev
```
Delete the pod and the namespace.

```bash
kubectl delete pod utrains -n dev
kubectl delete ns dev
```

6. Create a pod in a specific namespace exposing a port (80) using TCP protocol
Check the `03-pod-with-port.yaml` manifest file:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: utrains
  namespace: dev
  labels:
   app: utrains
spec:
  containers:
    - name: utrains-app
      image: httpd
      ports:
        - containerPort: 80
          name: http
          protocol: TCP
```
deploy and verify the pod and the namespace
```bash
kubectl create namespace dev
kubectl create -f pod-namespace.yaml
kubectl get pods -n dev
```
Delete the pod and the namespace.

```bash
kubectl delete pod utrains -n dev
kubectl delete ns dev
```

### Pods Quality of Service (QoS)
When Kubernetes creates a Pod, it assigns a QoS class to the pod based on the resource (CPU, memory) requests and limits defined in that pod. There are 3 QoS classes: **BestEffort, Burstable and Guaranteed**

- **BestEffort: No resources requests or limits defined**

The pod defined in the file `04-pod-qos-besteffort.yaml` is a BestEffort pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-besteffort
  labels:
   app: utrains
spec:
  containers:
    - name: nginx
      image: nginx
```
Apply the pod in the cluster and check
```bash
kubectl create -f 04-pod-qos-besteffort.yaml
kubectl get pods
kubectl describe pod qos-besteffort 
```
Check the QoS class defined in the pod description. 

Delete the pod.

```bash
kubectl delete pod qos-besteffort
```

- **Burstable: resources requests < resources limits**

The pod defined in the file `05-pod-qos-burstable.yaml` is a Burstable pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-burstable
  labels:
   app: utrains
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        limits:
          memory: "250Mi"
        requests:
          memory: "150Mi"
```
Apply the pod in the cluster and check
```bash
kubectl create -f 05-pod-qos-burstable.yaml
kubectl get pods
kubectl describe pod qos-burstable
```
Check the QoS class defined in the pod description. 

Delete the pod.

```bash
kubectl delete pod qos-burstable
```


- **Guaranteed: resources requests = resources limits**

The pod defined in the file `06-pod-qos-guaranteed.yaml` is a Guaranteed pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-guaranteed
  labels:
   app: utrains
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        limits:
          memory: "250Mi"
          cpu: "400m"
        requests:
          memory: "250Mi"
          cpu: "400m"
```
Apply the pod in the cluster and check
```bash
kubectl create -f 06-pod-qos-guaranteed.yaml
kubectl get pods
kubectl describe pod qos-guaranteed
```
Check the QoS class defined in the pod description. 

Delete the pod.

```bash
kubectl delete pod qos-guaranteed
```

### Pods Probes (health checks)
A **Probe** is like a diagnostic that is periodically performed by the Kubelet on the containers of a Pod. The result of these checks can be Success, Failure or Unknown. There are 3 types of probes in K8s:
- **LivenessProbe:** indicates whether the container is running or not. 

Open the file `07-pod-liveness-probe.yaml` and try to understand the given example.

- **ReadinessProbe:** indicates whether the container is ready to respond to requests or not. 

Open the file `08-pod-readiness-probe.yaml` and try to understand the given example.

- **StartupProbe:** indicates when a container application has started. This is very useful for slow starting containers. 

Open the file `09-pod-startup-probe.yaml` and try to understand the given example.


### Pods priorities (optional)
When creating pods, kubernetes also assign levels of priorities. By default, all the pods you create have the priority of 0 when no priority class is specified.
We have 3 levels of priorities: Critical, higher priority, lower priority. To use priorities, we need to define PriorityClasses and assign them to pods

Example: Check the files `10-pod-priotity-class.yaml` and `11-pod-with-priority.yaml`

- The `10-pod-priotity-class.yaml` file creates two priority classes 
- The `11-pod-with-priority.yaml` manifest creates two pods from each priority class

## Cleanup

```bash
# Simple pods
kubectl delete -f 01-simple-pod.yaml --ignore-not-found
kubectl delete -f 02-pod-namespace.yaml --ignore-not-found
kubectl delete -f 03-pod-with-port.yaml --ignore-not-found

# QoS pods
kubectl delete -f 04-pod-qos-besteffort.yaml --ignore-not-found
kubectl delete -f 05-pod-qos-burstable.yaml --ignore-not-found
kubectl delete -f 06-pod-qos-guaranteed.yaml --ignore-not-found

# Probes
kubectl delete -f 07-pod-liveness-probe.yaml --ignore-not-found
kubectl delete -f 08-pod-readiness-probe.yaml --ignore-not-found
kubectl delete -f 09-pod-startup-probe.yaml --ignore-not-found

# Priority class + pods (delete pods first, then class)
kubectl delete -f 11-pod-with-priority.yaml --ignore-not-found
kubectl delete -f 10-pod-priority-class.yaml --ignore-not-found

# If you created the dev namespace for these labs
kubectl delete ns dev --ignore-not-found
```
