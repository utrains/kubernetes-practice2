# Kubernetes Autoscaling on EKS - HPA, VPA, Cluster Autoscaler, Karpenter, KEDA

Autoscaling in Kubernetes is **not one thing**. It is at least five tools that each solve a different problem. This chapter walks through them in the order you typically reach for them in production.

## 1. HPA (CPU-based reactive autoscaling)

The **Horizontal Pod Autoscaler (HPA)** adjusts the number of pod replicas in a Deployment, ReplicaSet, or StatefulSet based on CPU/memory usage or custom metrics.

- **Goal**: keep resource utilization around a target (e.g., 50% CPU).
- **Example**: if pods are under high CPU load, HPA adds more pods.

### Prerequisites

- An EKS cluster created with `eksctl`.
- `kubectl` configured to access your cluster.
- Metrics Server (already included with `eksctl`-based clusters).

```bash
kubectl top nodes
kubectl top pods
kubectl get deployment -n kube-system
```

You should see `metrics-server` available and ready (2/2).

### Deploy a sample app with HPA

Apply `nginx-deploy-hpa.yaml`. It contains a Deployment, a Service, and an HPA targeted at 20% CPU utilization.

```bash
kubectl apply -f nginx-deploy-hpa.yaml
kubectl get deploy
kubectl get svc
kubectl get hpa
kubectl get pods
```

- **target**: 20% average CPU utilization
- **min**: 2 pods
- **max**: 10 pods

**WARNING**: you may see `<unknown>/20%` for 1-2 minutes, then `0%/20%`.

### Generate load

Open another terminal and run a load generator:

```bash
kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- sh
# inside the pod:
while true; do wget -q -O - http://nginx-service; done
```

In the first terminal:

```bash
kubectl get hpa -w
kubectl get pods
kubectl top pods
```

Stop the load generator (Ctrl-C) and watch HPA scale back down. It can take a few minutes.

## 2. VPA (right-sizing recommender)

The **Vertical Pod Autoscaler** does the opposite of HPA: instead of changing the **number** of pods, it changes their **CPU/memory requests** to right-size them. This solves the very common "I have no idea what to put in `resources.requests`" problem.

VPA has **3 update modes** (`spec.updatePolicy.updateMode`):

- **Off** - VPA only **reports recommendations**; never changes anything. Run with this for a week, then read recommendations: `kubectl describe vpa <name>`.
- **Initial** - applies the recommendation when a pod is first created, never afterwards. Safe.
- **Auto** - actively **evicts and recreates** pods to resize them.

**Warning**: VPA in `Auto` mode **can fight HPA** if both target the same metric (CPU/memory). The standard advice is: use HPA for CPU/memory and VPA in `Off`/`Initial` mode for recommendations, or use VPA `Auto` only when HPA is targeting custom metrics instead.

See `vpa-example.yaml`.

## 3. Cluster Autoscaler vs Karpenter (node-level capacity)

HPA adds **pods**. When pods can't be scheduled because there is no room on the cluster, you need to add **nodes**. There are two tools for this on EKS in 2026.

### Cluster Autoscaler

The original. Scales **EKS node groups** (Auto Scaling Groups under the hood) up and down based on pending pods. Manifest in `cluster-autoscaler-eks.yaml`.

Limitations:
- Reacts to whole node groups, not individual instances.
- You define node groups up front (e.g., "a group of m5.large").
- Slow to provision new nodes (ASG warmup).

### Karpenter (AWS)

**The AWS-recommended default for new EKS clusters in 2026.** Karpenter **skips node groups entirely** and provisions **individual EC2 instances** sized to fit pending pods. Result: faster scale-up, more efficient bin-packing, lower cost.

Manifest in `karpenter-nodepool.yaml` (a `NodePool` + `EC2NodeClass` with an on-demand + spot mix).

**Short version**: both add **nodes**, not pods. Cluster Autoscaler scales node groups; Karpenter provisions individual instances. New EKS clusters should default to Karpenter.

## 4. KEDA (event-driven, scale to zero)

HPA has one big limitation: **it cannot scale a Deployment to zero**. Its minimum is 1 replica. For queue consumers, batch workers, and any "wake up when there is work" service, you want **zero pods when idle** - that's where KEDA comes in.

**KEDA** (Kubernetes Event-Driven Autoscaling) is a controller that watches an external source (queue depth, Kafka lag, RabbitMQ messages, Prometheus query, AWS SQS, cron expression, etc.) and scales a Deployment 0..N based on it.

Common 2026 use cases:
- **SQS** consumers that should idle at 0 pods when the queue is empty.
- **Kafka** consumers that scale on consumer-group lag.
- **RabbitMQ** workers.
- Scheduled scale-up (warm a service before a known traffic spike).

See `keda-scaledobject.yaml` - an SQS-backed `ScaledObject` with `minReplicaCount: 0` and `maxReplicaCount: 10`.

## 5. Decision matrix

| Symptom | Reach for |
|---|---|
| Steady traffic that ebbs and flows with the day | **HPA** (CPU or memory) |
| "I have no idea what to set for requests/limits" | **VPA** (start in `Off` mode, read recommendations) |
| Pods stuck in `Pending` because no node has room | **Cluster Autoscaler** (existing setup) or **Karpenter** (new setup) |
| A queue / event-driven worker that should idle at 0 | **KEDA** |
| HTTP service driven by a custom metric (e.g., req/s) | **HPA** with an external/custom metric adapter |

Rule of thumb: HPA + Karpenter is the **default pair** for a new EKS workload in 2026. Add VPA in `Off` mode for visibility. Add KEDA when you have queue-driven services.

## Cleanup

```bash
# HPA + nginx demo
kubectl delete -f nginx-deploy-hpa.yaml

# VPA demo (only if VPA controller is installed)
kubectl delete -f vpa-example.yaml --ignore-not-found

# Cluster Autoscaler (reference manifest)
kubectl delete -f cluster-autoscaler-eks.yaml --ignore-not-found

# Karpenter NodePool (only if Karpenter is installed)
kubectl delete -f karpenter-nodepool.yaml --ignore-not-found

# KEDA ScaledObject (only if KEDA is installed)
kubectl delete -f keda-scaledobject.yaml --ignore-not-found

# Optional: load-generator pod if still hanging around
kubectl delete pod load-generator --ignore-not-found
```
