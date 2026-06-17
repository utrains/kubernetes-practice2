**Note**: This practice can be done on **Killercoda kubernetes playgrounds**

## The Replicaset
A ReplicaSet is a Kubernetes object that ensures a specified number of identical Pod replicas are running at any given time. If a Pod dies or is deleted, the ReplicaSet creates a new one. If you scale up, it adds more Pods; if you scale down, it removes extra Pods.

To define a replicaset, you must specify:
- A **Selector** that specifies how to identify Pods it can acquire
- A **number of replicas** indicating how many Pods it should be maintaining
- A **pod template** specifying the spec of the Pods that will be created.

**Example:** Create a replicaset running 3 replicas of pods using the httpd image

- Create the manifest called `replicaset-for-pods.yaml`. Remember the file can be found in this same folder of the repo.

The content should look like the following:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: webserver
spec:
  replicas: 3
  selector: 
    matchLabels:
      app: webserver
  template:
    metadata:
      labels:
        app: webserver
    spec:
      containers:
        - name: webserver
          image: httpd
```

- Apply the file in the cluster and verify the created objects
```bash 
kubectl apply -f replicaset-for-pods.yaml
# check the replicaset
kubectl get rs
# Check the pods
kubectl get pods
# Check the nodes where the pods are placed
kubectl get pods -o wide
```

- Describe the replicaset and the a pod
```bash
kubectl describe rs webserver 
kubectl describe pod <pod-name-here>
```
- Delete a pod and verify that the replicaset creates a new one
```bash
kubectl delete pod <pod-name-here>
```
verify
```bash
kubectl get pods
```

- Delete the replicaset
```bash
kubectl delete rs webserver
```

## Cleanup

```bash
kubectl delete -f replicaset-for-pods.yaml --ignore-not-found
```
