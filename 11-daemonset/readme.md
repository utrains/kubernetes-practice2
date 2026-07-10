**Note**: This practice can be done on **Killercoda kubernetes playgrounds**

## The Daemonset
Daemonsets ensure that a copy of a desired pod run on all (or some) nodes of the cluster.It can be used in the following cases:
- To run a daemon for logs collection on each node (like Fluentd or logstash.
- To run a daemon for cluster storage on each node (like glusterd ceph) 
- To run a daemon for logs rotation and cleaning log files.
- To run a daemon for node monitoring (such as Prometheus Node Exporter, collectd.

Just like Deployments, Daemonsets have two strategies types:
- RollingUpdate: old DaemonSet pods will be killed and replaced progressively.
- OnDelete: new DaemonSet pods will only be created when you manually delete old pods.

Example 1: Create a daemonset for node monitoring using Prometheus Node Exporter. Check `prometheus-daemonset.yaml`
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: prometheus-daemonset
spec:
  selector:
    matchLabels:
      tier: monitoring
      name: prometheus-exporter
  template:
    metadata:
      labels:
        tier: monitoring
        name: prometheus-exporter
    spec:
      containers:
      - name: prometheus
        image: prom/node-exporter
        ports:
        - containerPort: 80
```
Apply the Daemonset in the cluster and verify it is running on all the nodes

```bash
kubectl apply -f prometheus-daemonset.yaml
kubectl get pods -o wide
kubectl delete -f prometheus-daemonset.yaml
```

Example 2: Create a daemonset which runs the fluentd-elasticsearch Docker image in the cluster. Check `fluentd-daemonset.yaml`

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      containers:
      - name: fluentd-elasticsearch
        image: quay.io/fluentd_elasticsearch/fluentd:v2.5.2
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      # it may be desirable to set a high priority class to ensure that a DaemonSet Pod
      # preempts running Pods
      # priorityClassName: important
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```

Apply the Daemonset in the cluster and verify it is running on all the nodes

````bash
kubectl apply -f fluentd-daemonset.yaml
kubectl get pods -n kube-system -o wide
kubectl delete -f fluentd-daemonset.yaml
```

## Cleanup

```bash
kubectl delete -f prometheus-daemonset.yaml --ignore-not-found
kubectl delete -f fluentd-daemonset.yaml --ignore-not-found
```
