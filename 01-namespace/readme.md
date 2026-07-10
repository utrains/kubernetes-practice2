**Note**: This practice can be done on **Killercoda kubernetes playgrounds**

## Namespaces in kubernetes
A Namespace is a way to logically divide your resources into groups within the cluster. This is very useful when many teams create resources in a single cluster. 
Each object created in the cluster belongs to a namespace.

By default, kubernetes starts with 4 namespaces:
- default: for the resources you create with no namespace 
- kube-system: for the objects created by the Kubernetes system 
- kube-public: for the resources that should be visible and publicly readable
- kube-node-lease: where Node Lease objects are stored

To create a namespace, you can use the command `kubectl create namespace <name>` or create a manifest where you can define your namespace spec:

**Example:** Create a namespace called dev for the dev team. 
- Create a file called `namespace.yaml` 

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```
Note: You can find this file `namespace.yaml` in this same folder.
- Create the namespace in the cluster using the command:
```bash
kubectl create -f namespace.yaml
``` 

or 

```bash
kubectl apply -f namespace.yaml
```

- You can verify with

```bash
kubectl get namespace
kubectl get ns
```

- You can describe the namespace with:

```bash
kubectl describe ns dev
```

To delete the namespace, run the command `kubectl delete ns <name>` as follows:

```bash
kubectl delete ns dev
```

## Cleanup

```bash
kubectl delete -f namespace.yaml --ignore-not-found
kubectl delete ns dev --ignore-not-found
```