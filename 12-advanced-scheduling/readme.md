**Note**: This practice can be done on **Killercoda kubernetes playgrounds with 2 nodes**

## Advanced scheduling techniques in Kubernetes

### Definitions
**Scheduling** is the process of placing pods on nodes for the applications to run as desired

**The Kube-scheduler** performs scheduling in kubernetes clusters by placing pods on nodes to optimize resources and maintain high availability of deployed applications.

Kubernetes allows you to define your scheduling algorithms or to use advanced scheduling techniques such as: 
- **Node Selector,** 
- **Node Affinity,** 
- **Pod Affinity/Anti-Affinity,** 
- **Taints and Tolerations**

**Note: To better observe the scheduling effect, you need a cluster with at least 2 worker nodes**

### The Node Selector
Here the goal is to constraint the scheduler to place the pod on a specific node. To perform this, you need to add a label on the node then use that label in the pod specifications with the `nodeSelector` field.
- To add a label to a node, we can use the `kubectl label` command:
```bash
kubectl label nodes <node-name> key=value
# Example
kubectl label nodes node01 disktype=ssd
kubectl get nodes --show-labels
kubectl get nodes --show-labels | grep ssd 
```

- To create a pod that gets scheduled to your chosen node you must use the `nodeSelector` field and include the label you defined on the node. Open and verify the file `pod-node-selector.yaml` in the `01-node-selector` folder

Create the pod manifest `pod-node-selector.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-node-selector
  labels:
    env: test
spec:
  containers:
  - name: nginx
    image: nginx
  nodeSelector:
    disktype: ssd
```
Apply the pod in the cluster and verify where it has been placed. The pod should run on the node with the label `disktype=ssd`

```bash
kubectl apply -f pod-node-selector.yaml
kubectl get pods -o wide
kubectl delete -f pod-node-selector.yaml
```

You can also schedule a pod to one specific node via setting `nodeName`. 

Open and verify the `pod-node-name.yaml` manifest in the `01-node-selector` folder.

Create the pod manifest `pod-node-name.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-node-name
spec:
  nodeName: node01 # schedule pod to specific node
  containers:
  - name: nginx
    image: nginx
```
Apply the pod in the cluster and verify where it has been placed. The pod should run on the node with the name `node01`

```bash
kubectl apply -f pod-node-name.yaml
kubectl get pods -o wide
kubectl delete -f pod-node-name.yaml
```

**Note:** When a there is no node selector specified in a pod, it can be placed on any node in the cluster. But when a pod has a node selector, it will remain pending if no node has the corresponding label.

### The Node Affinity

Node affinity is very similar to the node selector technique, but it has a better way of expressing constraints. Node affinity comes in two flavors: 
- **preferredDuringSchedulingIgnoredDuringExecution** (soft type)
- **requiredDuringSchedulingIgnoredDuringExecution** (hard type)

#### preferredDuringScheduling
1. The pod PREFERS to be scheduled on the nodes that meets the requirements. 
2. However the pod can still be placed on a node that does not meet one or more of the specified requirements.

#### requiredDuringScheduling
1. If the node meets the pod's requirements, then the pod can be scheduled there.
2. If no node meets the requirements, the pod remains pending.

#### IgnoredDuringExecution
1. A Pod is already running on the node 
2. The node no longer meets the requirements: The pod cannot be unscheduled, it continues its execution

**Examples:** Open the `02-node-affinity` folder
1. Create the pod with the manifest `pod-node-affinity-preferred.yaml` that prefers to be placed on the node with the label `disktype=ssd`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-node-affinity-preferred
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd          
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
``` 
Apply and verify. The pod will prefer to be palced of the node with label `disktype=ssd`. But it can also be placed elsewhere.

```bash
kubectl apply -f pod-node-affinity-preferred.yaml
kubectl get pods -o wide
kubectl delete -f pod-node-affinity-preferred.yaml
```

2. Create the pod with the manifest `pod-node-affinity-required.yaml` that require to be placed on the node with the label `disktype=ssd`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-node-affinity-required
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd            
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
``` 
Apply and verify that the pod is placed on the node with label `disktype=ssd`

```bash
kubectl apply -f pod-node-affinity-required.yaml
kubectl get pods -o wide
# unlabel the node to see if the ignoredDuringExecution works well
kubectl label node node01 disktype-
kubectl get pods
# the pod should continue running
kubectl delete -f pod-node-affinity-required.yaml
# relabel the node to continue practice
kubectl label node node01 disktype=ssd
```

#### Notes: 
- There is no **Node Anti-Affinity** field. To define the node anti-affinity behaviour, we use the value of the `operator` parameter. The `operator` parameter can take values like: 
    - In, 
    - NotIn, 
    - Exists, 
    - DoesNotExist, 
    - Gt (greater than)
    - Lt (lower than). 
- So you can use `NotIn` and `DoesNotExist` to configure **node anti-affinity** behaviour.

Example: Create the pod with the manifest `pod-node-anti-affinity.yaml` that must not be placed on the node with the label `disktype=ssd`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-node-anti-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: NotIn
            values:
            - ssd            
  containers:
  - name: nginx
    image: nginx
    imagePullPolicy: IfNotPresent
```

Apply and verify, the pod **should not be placed** on the node with label `disktype=ssd`

```bash
kubectl apply -f pod-node-anti-affinity.yaml
kubectl get pods -o wide
kubectl delete -f pod-node-anti-affinity.yaml
```


#### Notes
- You can define a pod with both hard and soft type
- You can define pods with multiple node affinity constraints. Open and verify the manifests `pod-with-preferred-node-affinity-multiple.yaml` and `pod-with-required-node-affinity-multiple.yaml`

### The Pod Affinity/Anti-Affinity

- **Pod affinity** enable us to schedule pods in the same location. (Schedule pod A near pod B)

**Example:** Create a podA that run the httpd image, then create a podB near the podA. The manifest are found in the `03-pod-affinity` folder

1. Create the podA with the manifest `podA.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-a
  labels:
   app: web
spec:
  containers:
    - name: httpd
      image: httpd
```
Apply and verify the node where the pod is placed
```bash
kubectl apply -f podA.yaml
kubectl get pods -o wide
```
2. Create the podB using the manifest `pod-affinity.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-b
  labels:
   app: utrains
spec:
  containers:
    - name: httpd
      image: httpd
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - web
        topologyKey: "kubernetes.io/hostname"
```
Apply and verify the node where the pod is placed. It should be on the same node with podA.
```bash
kubectl apply -f pod-affinity.yaml
kubectl get pods -o wide
```


- **Pod anti-affinity** enable us to avoid scheduling pods in the same location. (Do not schedule pod A near pod C).

**Example**: Create a podA that run the httpd image, then create a podC not near the podA. The manifest are found in the `03-pod-affinity` folder

Note: The podA was created previously, so just create the podC with the manifest `pod-anti-affinity.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-c
  labels:
   app: utrains
spec:
  containers:
    - name: httpd
      image: httpd
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - web
        topologyKey: "kubernetes.io/hostname"
```
Apply and verify the node where the pod is placed. It **should not be placed** on the same node with podA.
```bash
kubectl apply -f pod-anti-affinity.yaml
kubectl get pods -o wide
```
Delete the 3 pods
```bash
kubectl delete -f pod-anti-affinity.yaml
kubectl delete -f pod-affinity.yaml
kubectl delete -f podA.yaml
```

Just like the node affinity, it comes with a soft and a hard type (`preferredDuringSchedulingIgnoredDuringExecution`, `requiredDuringSchedulingIgnoredDuringExecution`)

**A good usecase of pod affinity can be found in the manifest `pod-affinity-use-cases.yaml`**

### Taints and tolerations

- Taints are properties set on nodes that allow them to repel a pod or a set of pods
- Tolerations are properties set on pods that enables them to be scheduled on the nodes with the matching taints.

**Note:** The control plane node is generally tainted in clusters.

#### How to taint a node

To taint a node, you need to use the `kubectl taint` command with: **The key, the value and the effect**
```bash 
kubectl taint nodes node-name key=value:effect
```
- The **key** and the **value** (key=value) are used to identify the taint (just like a label).
- The **taint effect** defines what happens to pods that do not tolerate the taint.

There are three taint effects: 
-**NoSchedule:** Pods that do not tolerate the taint cannot be scheduled on the node. Running pods are not evicted 
- **PreferNoSchedule:** Pods that do not tolerate the taint prefer not to be scheduled on the node. Running pods are not evicted  
- **NoExecute:** Pods that do not tolerate the taint cannot be scheduled on the node. Running pods that do not tolerate the taint are evicted.

Example: Taint 2 nodes in your cluster with the following specs: for the first node `color=pink:NoSchedule` for the second `color=yellow:NoSchedule`
```bash
kubectl taint node <node-name> color=pink:NoSchedule
kubectl taint node <node-name> color=yellow:NoSchedule
```
**Note**: Replace <node-name> with the actual name of your node. **If you are working in a Killercoda playground, you can set the taint on the controlplane node.**

#### How to set tolerations for pods
You specify a toleration for a pod in the `tolerations` field in the pod specifications. In this field, you use the **key, value, effect** but also `operator` parameter

The operator parameter can take two values: either `Equal` (this is the default) or `Exists`
- **Equal**: The key/value/effect field defined in the pod toleration must match the ones in the node taint
- **Exists**:
    - if **key/effect** are defined, they must match the taint
    - if **key/effect** are empty, the pod will tolerate any node
    - if **effect** is empty, the pod will tolerate any node tainted with the specified key

**Examples:** The maifests are found in the folder `04-taints-tolerations`

1. Create a pod that will tolerate the `pink` node
Create the pod with the manifest `pod-toleration-equal1.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webserver1
spec:
  containers:
    - name: httpd
      image: httpd
      ports:
        - containerPort: 80
          name: http
          protocol: TCP
  tolerations:
  - key: "color"
    operator: "Equal"
    value: "pink"
    effect: "NoSchedule"
```
Apply the pod in the cluster and verify that the pod is placed on the node with the taint: `color=pink:NoSchedule`

```bash
kubectl create -f pod-toleration-equal1.yaml
kubectl get pods -o wide
```


2. Create a pod that will tolerate a node with the color `black`

Create the pod with the manifest `pod-toleration-equal2.yaml`
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webserver2
spec:
  containers:
    - name: httpd
      image: httpd
      ports:
        - containerPort: 80
          name: http
          protocol: TCP
  tolerations:
  - key: "color"
    operator: "Equal"
    value: "black"
    effect: "NoSchedule"
```
Apply the pod in the cluster and verify that the pod stays **Pending** because there is node node with that taint in the cluster.
```bash
kubectl create -f pod-toleration-equal2.yaml
kubectl get pods -o wide
```


3. Create a pod that tolerate any node that has a color set

Create the pod with the manifest `pod-toleration-exists1.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webserver3
spec:
  containers:
    - name: httpd
      image: httpd
      ports:
        - containerPort: 80
          name: http
          protocol: TCP
  tolerations:
  - key: "color"
    operator: "Exists"
    effect: "NoSchedule"
```
Apply the pod in the cluster and verify that the pod runs on any of the node that has a color set
```bash
kubectl create -f pod-toleration-exists1.yaml
kubectl get pods -o wide
```


4. Create a pod that tolerate a node with the taint `key=gpu` and `effect=NoExecute`

Create the pod with the manifest `pod-toleration-exists2.yaml`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webserver4
spec:
  containers:
    - name: httpd
      image: httpd
      ports:
        - containerPort: 80
          name: http
          protocol: TCP
  tolerations:
  - key: "gpu"
    operator: "Exists"
    effect: "NoExecute"
```
Apply the pod in the cluster and verify that the pod stays **Pending** because there is no taint key that satisfies the pod toleration.
```bash
kubectl create -f pod-toleration-exists2.yaml
kubectl get pods -o wide
kubectl describe pod webserver4
```

Delete all the pods.
```bash
kubectl delete pod webserver1
kubectl delete pod webserver2
kubectl delete pod webserver3
kubectl delete pod webserver4
```

## Cleanup

```bash
# Node selector
kubectl delete -f 01-node-selector/pod-node-selector.yaml --ignore-not-found
kubectl delete -f 01-node-selector/pod-node-name.yaml --ignore-not-found

# Node affinity
kubectl delete -f 02-node-affinity/pod-node-affinity-preferred.yaml --ignore-not-found
kubectl delete -f 02-node-affinity/pod-node-affinity-required.yaml --ignore-not-found
kubectl delete -f 02-node-affinity/pod-node-anti-affinity.yaml --ignore-not-found
kubectl delete -f 02-node-affinity/pod-preferred-node-affinity-multiple.yaml --ignore-not-found
kubectl delete -f 02-node-affinity/pod-required-node-affinity-multiple.yaml --ignore-not-found

# Pod affinity / anti-affinity
kubectl delete -f 03-pod-affinity/podA.yaml --ignore-not-found
kubectl delete -f 03-pod-affinity/pod-affinity.yaml --ignore-not-found
kubectl delete -f 03-pod-affinity/pod-anti-affinity.yaml --ignore-not-found
kubectl delete -f 03-pod-affinity/pod-affinity-use-cases.yaml --ignore-not-found

# Taints / tolerations
kubectl delete -f 04-taints-tolerations/pod-toleration-equal1.yaml --ignore-not-found
kubectl delete -f 04-taints-tolerations/pod-toleration-equal2.yaml --ignore-not-found
kubectl delete -f 04-taints-tolerations/pod-toleration-exists1.yaml --ignore-not-found
kubectl delete -f 04-taints-tolerations/pod-toleration-exists2.yaml --ignore-not-found

# Remove any taints you added to your nodes during the lab, e.g.:
# kubectl taint nodes <node-name> gpu=true:NoSchedule-
```

