**Note**: This practice can be done on **Killercoda kubernetes playgrounds**
## The Network policy
By default, **all traffic is allowed** within the cluster: pods can accept traffic from any source within the cluster. 

To enhance security in a cluster, **Network Policy** can be used to restrict traffic to/from a specific Pod.

When defining a network policy, we can specify the:
- **Incoming Traffic - Ingress**
- **Outgoing Traffic - Egress**

## Scenario: 

We want to deploy 3 pods in the cluster with the following specifications:

- Deploy two pods (pod-a and pod-b) in a namespace (test-ns).
- Deploy a third pod (pod-c) in a different namespace (dev-ns).
- Apply a Network Policy that allows traffic to pod-a only from pod-b, blocking others.

## Solution
1. Let's create the namespaces, the pods and the services to expose them using the content of the `01-ns-pods-svc.yaml` file

The content should look like the following:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: test-ns
---
apiVersion: v1
kind: Namespace
metadata:
  name: dev-ns
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-a
  namespace: test-ns
  labels:
    app: pod-a
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
  name: pod-a-svc
  namespace: test-ns
spec:
  selector:
    app: pod-a
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-b
  namespace: test-ns
  labels:
    app: pod-b
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
  name: pod-b-svc
  namespace: test-ns
spec:
  selector:
    app: pod-b
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-c
  namespace: dev-ns
  labels:
    app: pod-c
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
  name: pod-c-svc
  namespace: dev-ns
spec:
  selector:
    app: pod-c
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```
2. Apply the file in the cluster and verify the objects created
```bash
kubectl apply 01-ns-pods-svc.yaml
kubectl get pods -A
kubectl get svc -A
```

3. Test the network connectivity from the pods
- Test if pod-b can talk to pod-a

```bash
kubectl exec -n test-ns pod-b -- curl -m 3 http://pod-a-svc.test-ns  # Should work 200 OK
```
- Test if pod-c can talk to pod-a

```bash
kubectl exec -n dev-ns pod-c -- curl -m 3 http://pod-a-svc.test-ns  # Should work 200 OK
```

- Test if pod-a can access pod-b
```bash
kubectl exec -n test-ns pod-a -- curl -m 3 http://pod-b-svc.test-ns # Should work 200 OK
```

- Test if pod-a can access external internet
```bash
kubectl exec -n test-ns pod-a -- curl -m 3 http://google.com # Should work 200 OK
```


4. Create the Network policy to control the traffic

Create a file with the content of the manifest `network-policy.yaml`

The content should look like the following

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-ingress-egress
  namespace: test-ns
spec:
  podSelector:
    matchLabels:
      app: pod-a
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: pod-b
      ports:
        - protocol: TCP
          port: 80
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: pod-b
      ports:
        - protocol: TCP
          port: 80
```
This network policy specifies that **pod-a can only accept traffic from pod-b** and also **pod-a can only send traffic to pod-b**

Apply the file to the cluster and verify
```bash
kubectl apply -f network-policy.yaml
kubectl get networkpolicy -A
kubectl describe networkpolicy restrict-ingress-egress -n test-ns
```

5. Test the network connectivity from the pods
- Test if pod-b can talk to pod-a

```bash
kubectl exec -n test-ns pod-b -- curl -m 3 http://pod-a-svc.test-ns  # Should work 200 OK
```
- Test if pod-c can talk to pod-a

```bash
kubectl exec -n dev-ns pod-c -- curl -m 3 http://pod-a-svc.test-ns  # Should Fail
```

- Test if pod-a can access pod-b
```bash
kubectl exec -n test-ns pod-a -- curl -m 3 http://pod-b-svc.test-ns # Should work 200 OK
```

- Test if pod-a can access external internet
```bash
kubectl exec -n test-ns pod-a -- curl -m 3 http://google.com # Should fail
```

- Test if pod-a can access pod-c
```bash
kubectl exec -n test-ns pod-a -- curl -m 3 http://pod-c-svc.dev-ns # Should fail
```
**WARNING: This might not work accurately depending on the cluster on which you are working. Not all cluster networking system support network policies. Just try to understand the concept!**

## Practice on denying all traffic

Fist delete the network policy currently applied on the pods
```bash
kubectl delete -f network-policy.yaml
```
1. Apply a Network Policy that DENIES ALL Ingress and Egress


Create the network policy using the content in the manifest `04-deny-all-ingress-egress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
```
Apply the file to the cluster and test
```bash
kubectl apply -f 04-deny-all-ingress-egress.yaml
kubectl get networkpolicy -A
# test pod-b to pod-a Should fail (because all ingress is denied).
kubectl exec -n test-ns pod-b -- curl -m 3 http://pod-a-svc.test-ns
# test pod-c to pod-a Should fail (because all ingress is denied).
kubectl exec -n dev-ns pod-c -- curl -m 3 http://pod-a-svc.test-ns
# test pod-a to pod-b Should fail (because all egress is denied).
kubectl exec -n test-ns pod-a -- curl -m 3 http://pod-b-svc.test-ns
# test pod-a to internet Should fail (because all egress is denied).
kubectl exec -n test-ns pod-a -- curl -m 3 http://google.com
```
Delete the network policies
```bash
kubectl delete -f 04-deny-all-ingress-egress.yaml
```
The file `04-deny-all-ingress-egress.yaml` is the longer version of the file `05-deny-all-traffic.yaml`

## Clean Up

```bash
kubectl delete -f ns-pods-svc.yaml
```
