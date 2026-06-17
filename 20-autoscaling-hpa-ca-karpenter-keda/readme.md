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

---

## 2. VPA (Vertical Pod Autoscaler)

### What is VPA?

The **Vertical Pod Autoscaler** changes a pod's CPU/memory **requests** to right-size it, instead of changing the number of replicas. It solves the very common "I have no idea what to set for `resources.requests`" problem.

### A brief history

VPA was the second autoscaler created by SIG-Autoscaling (after HPA), starting around 2018. It lives in the same `kubernetes/autoscaler` repository as Cluster Autoscaler. It reached **v1.0 in 2024** and the current default at the time of this rewrite is **v1.7.0** (requires Kubernetes 1.28+). Until K8s 1.33, VPA could only resize pods by evicting and recreating them. K8s 1.33's `InPlacePodVerticalScaling` alpha lets VPA's new `InPlace` and `InPlaceOrRecreate` modes resize pods without restarting.

### Why it matters

Most teams pick `requests` / `limits` numbers out of thin air on day one and never revisit them. VPA reads actual usage and tells you the right values — either as a recommendation, or by applying them automatically.

### The actual update modes

`spec.updatePolicy.updateMode` accepts **six** values (verified against the upstream `types.go`):

| Mode | Behavior |
|---|---|
| `Off` | VPA only **reports recommendations**; never changes anything. Run in this mode for a week to gather data, then read `kubectl describe vpa <name>`. |
| `Initial` | Applies the recommendation only when a pod is first created; never afterwards. Safe. |
| `Recreate` | Evicts and recreates pods to resize them. This is the new default. |
| `Auto` | **Deprecated.** Currently equivalent to `Recreate`. Will be removed in a future API version. |
| `InPlaceOrRecreate` | Tries to resize in-place; falls back to recreate if not possible. Requires K8s 1.33+ with the `InPlacePodVerticalScaling` feature gate. |
| `InPlace` | Only resize in-place; never evict. Requires K8s 1.33+ and the VPA `InPlace` feature gate. |

> **Warning**: VPA in any mode that mutates resources can fight HPA if both target the same metric (CPU/memory). The standard advice is to use HPA for CPU/memory and VPA in `Off` mode for recommendations, or use VPA's resize modes only when HPA targets custom metrics.

### When to use vs not use it

- **Use it in `Off` mode for visibility** on every new workload. Almost free, almost no risk.
- **Use it in `Recreate` mode** for batch jobs, internal tooling, and steady workloads where eviction is tolerable.
- **Avoid it on workloads that already use HPA on CPU/memory** unless you scope VPA only to set the lower bound.

### Prerequisites

- EKS cluster (any supported version is fine: VPA 1.7 works on K8s 1.28+).
- `kubectl` and `git` installed locally.
- Metrics Server installed in the cluster (already present on EKS).

### Install (upstream script)

VPA does not have an official Helm chart — the upstream install method is the `hack/vpa-up.sh` script in the `kubernetes/autoscaler` repo:

```bash
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler
git checkout vpa-release-1.7

./hack/vpa-up.sh
```

The script installs three components into `kube-system`:

- **recommender** — reads metrics, computes recommendations.
- **updater** — evicts pods that need to be resized.
- **admission-controller** — mutates pods at admission time so they come back with the new requests.

It also generates a TLS cert/secret used by the admission controller.

### Verify

```bash
kubectl get pods -n kube-system | grep vpa
# expect: vpa-recommender, vpa-updater, vpa-admission-controller
kubectl get crds | grep verticalpodautoscaler
```

### Sample manifest (`vpa-example.yaml`)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hamster
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hamster
  template:
    metadata:
      labels:
        app: hamster
    spec:
      containers:
      - name: hamster
        image: registry.k8s.io/ubuntu-slim:0.1
        resources:
          requests:
            cpu: 100m
            memory: 50Mi
        command: ["/bin/sh"]
        args:
        - "-c"
        - "while true; do timeout 0.5s yes >/dev/null; sleep 0.5s; done"
---
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: hamster-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind:       Deployment
    name:       hamster
  updatePolicy:
    updateMode: "Off"          # change to "Recreate" to let VPA actually resize
```

### Apply + verify

```bash
kubectl apply -f vpa-example.yaml
kubectl get vpa
kubectl describe vpa hamster-vpa
# look under "Recommendation:" for target / lowerBound / upperBound CPU & memory
```

It can take a few minutes for the recommender to produce values.

### Cleanup

```bash
kubectl delete -f vpa-example.yaml
# tear down VPA itself:
cd autoscaler/vertical-pod-autoscaler
./hack/vpa-down.sh
```

---

## 3. Cluster Autoscaler (node-level capacity, ASG-based)

### What is Cluster Autoscaler?

The **Kubernetes Cluster Autoscaler (CA)** scales the number of nodes in your cluster up and down. On AWS it does this by adjusting the desired capacity of EC2 Auto Scaling Groups (ASGs). It is the **older** of the two node-level autoscalers and is what AWS still documents alongside Karpenter today.

### A brief history

Cluster Autoscaler launched in 2016 in the `kubernetes/autoscaler` repository alongside HPA. For most of EKS's life it was *the* answer to "I need more nodes." It is solid, conservative, and works on every cloud — but it always reacts in terms of pre-defined ASGs, which can leave money on the table.

### Why it matters

If your cluster uses EKS managed node groups (or self-managed ASGs), CA is the simplest way to make the cluster scale itself.

### When to use vs not use it

- **Use CA** when you already have well-tuned node groups and want minimal moving parts.
- **Use Karpenter instead** for greenfield EKS clusters — see the next section.

### Prerequisites

- EKS cluster with one or more **managed node groups** (or self-managed ASGs).
- ASG tags `k8s.io/cluster-autoscaler/enabled=true` and `k8s.io/cluster-autoscaler/<cluster-name>=owned` on every ASG you want CA to control. `eksctl create nodegroup --asg-access` adds these for you.
- IAM OIDC provider associated with the cluster.
- `kubectl`, `eksctl`, `helm`.

### 1. Create the IAM policy

The upstream README publishes the JSON for the full features policy. Save the JSON below as `cluster-autoscaler-policy.json` (this is the **Full Cluster Autoscaler Features Policy (Recommended)** from the upstream `cluster-autoscaler/cloudprovider/aws/README.md`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "ec2:DescribeImages",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:GetInstanceTypesFromInstanceRequirements",
        "eks:DescribeNodegroup"
      ],
      "Resource": ["*"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": ["*"]
    }
  ]
}
```

```bash
aws iam create-policy \
  --policy-name AmazonEKSClusterAutoscalerPolicy \
  --policy-document file://cluster-autoscaler-policy.json
```

### 2. Create the IRSA ServiceAccount

```bash
eksctl create iamserviceaccount \
  --cluster=dev-cluster \
  --namespace=kube-system \
  --name=cluster-autoscaler \
  --attach-policy-arn=arn:aws:iam::<your-account-id>:policy/AmazonEKSClusterAutoscalerPolicy \
  --override-existing-serviceaccounts \
  --region=us-east-1 \
  --approve
```

### 3. Install via Helm

```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm repo update

helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=dev-cluster \
  --set awsRegion=us-east-1 \
  --set rbac.serviceAccount.create=false \
  --set rbac.serviceAccount.name=cluster-autoscaler
```

> **Version pin**: the Cluster Autoscaler container image tag must match your Kubernetes minor version (CA `v1.29.x` for K8s 1.29, CA `v1.30.x` for K8s 1.30, etc.). The Helm chart picks a sensible default but you can override with `--set image.tag=v1.30.0`. Check the [autoscaler releases page](https://github.com/kubernetes/autoscaler/releases) for the exact patch version that matches your cluster.

### 4. Verify

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler --tail=50
# look for: "Cluster Autoscaler vX.Y.Z"
```

### 5. Test

Apply a deployment whose pods do not fit on the current nodes (e.g., 30 replicas of a 1-CPU pod on 2 small nodes):

```bash
kubectl create deployment overflow --image=nginx --replicas=30
kubectl set resources deployment overflow --requests=cpu=500m
kubectl get pods -w     # expect: many in Pending
# CA should detect Pending pods and grow the ASG within a few minutes
kubectl get nodes -w
```

Then delete the deployment and CA will scale the ASG back down (default: after ~10 minutes of underutilization).

### 6. Cleanup

```bash
kubectl delete deployment overflow
helm uninstall cluster-autoscaler -n kube-system
eksctl delete iamserviceaccount --cluster=dev-cluster --name=cluster-autoscaler --namespace=kube-system --region=us-east-1
aws iam delete-policy --policy-arn arn:aws:iam::<your-account-id>:policy/AmazonEKSClusterAutoscalerPolicy
```

---

## 4. Karpenter (node-level capacity, instance-by-instance)

### What is Karpenter?

**Karpenter** is AWS's open-source Kubernetes node autoscaler. Instead of scaling ASGs, it provisions individual EC2 instances sized to fit the actually-pending pods. It consolidates underused nodes automatically.

### A brief history

Karpenter was announced by AWS at re:Invent 2021 and became GA in 2022. It joined the CNCF as a Sandbox project in 2023, donated to SIG-Autoscaling. The provider-agnostic core lives at `kubernetes-sigs/karpenter`; the AWS implementation at `aws/karpenter-provider-aws`. The current release at the time of this rewrite is **v1.13.0**, supported on K8s 1.36 in the official getting-started guide.

### Why it matters

Karpenter looks at *all* the pending pods, computes the cheapest set of instance types that will fit them, launches those instances directly via EC2 RunInstances, and joins them to the cluster. It then continuously bin-packs and consolidates — terminating underused nodes and replacing them with smaller cheaper ones.

Net effect vs CA: **faster scale-up, much better bin-packing, lower spend** — at the cost of one more controller you have to operate.

### When to use vs not use it

- **Karpenter** is the default for new EKS clusters in 2026. AWS's official autoscaling guide leads with it.
- **Cluster Autoscaler** is fine for an existing cluster with well-tuned ASGs that you do not want to disturb.
- **EKS Auto Mode** is AWS's fully managed take on Karpenter — even less to operate, but less flexibility. Worth a look if you do not need custom NodePools.

### Prerequisites

The official getting-started guide expects these tools:

- AWS CLI configured (`aws sts get-caller-identity` works)
- `kubectl`
- `eksctl` (>= v0.202.0)
- `helm`

Set environment variables (values from the upstream guide):

```bash
export KARPENTER_NAMESPACE="kube-system"
export KARPENTER_VERSION="1.13.0"
export K8S_VERSION="1.36"
export AWS_PARTITION="aws"
export CLUSTER_NAME="${USER}-karpenter-demo"
export AWS_DEFAULT_REGION="us-west-2"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export TEMPOUT="$(mktemp)"
```

### 1. Create the supporting AWS infrastructure (CloudFormation)

The upstream guide ships a CloudFormation template that creates the Karpenter controller IAM role, node IAM role, instance profile, SQS interruption queue, and EventBridge rules:

```bash
curl -fsSL "https://raw.githubusercontent.com/aws/karpenter-provider-aws/v${KARPENTER_VERSION}/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml" > "${TEMPOUT}"

aws cloudformation deploy \
  --stack-name "Karpenter-${CLUSTER_NAME}" \
  --template-file "${TEMPOUT}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${CLUSTER_NAME}"
```

### 2. Create the EKS cluster wired up to Karpenter

Use `eksctl` with the upstream ClusterConfig (managed node group flavor). This creates the cluster, the OIDC provider, the IRSA Pod Identity association for the Karpenter ServiceAccount, and wires the Karpenter node role into the cluster's auth mapping:

```bash
eksctl create cluster -f - <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_DEFAULT_REGION}
  version: "${K8S_VERSION}"
  tags:
    karpenter.sh/discovery: ${CLUSTER_NAME}

iam:
  withOIDC: true
  podIdentityAssociations:
  - namespace: "${KARPENTER_NAMESPACE}"
    serviceAccountName: karpenter
    roleName: ${CLUSTER_NAME}-karpenter
    permissionPolicyARNs:
    - arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerNodeLifecyclePolicy-${CLUSTER_NAME}
    - arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerIAMIntegrationPolicy-${CLUSTER_NAME}
    - arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerEKSIntegrationPolicy-${CLUSTER_NAME}
    - arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerInterruptionPolicy-${CLUSTER_NAME}
    - arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerResourceDiscoveryPolicy-${CLUSTER_NAME}

iamIdentityMappings:
- arn: "arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}"
  username: system:node:{{EC2PrivateDNSName}}
  groups:
  - system:bootstrappers
  - system:nodes

managedNodeGroups:
- instanceType: m5.large
  amiFamily: AmazonLinux2023
  name: ${CLUSTER_NAME}-ng
  desiredCapacity: 2
  minSize: 1
  maxSize: 10

addons:
- name: eks-pod-identity-agent
EOF
```

Create the EC2 Spot service-linked role (idempotent — ignore the "already exists" error):

```bash
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
```

### 3. Install Karpenter via Helm (from public ECR)

```bash
helm registry logout public.ecr.aws

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace "${KARPENTER_NAMESPACE}" --create-namespace \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.interruptionQueue=${CLUSTER_NAME}" \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --wait
```

### 4. Verify

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
kubectl get crds | grep karpenter
# expect: nodepools.karpenter.sh, nodeclaims.karpenter.sh, ec2nodeclasses.karpenter.k8s.aws
```

### 5. Sample NodePool + EC2NodeClass (`karpenter-nodepool.yaml`)

Apply the upstream getting-started NodePool. It says "give me on-demand AMD64 Linux nodes from generation 3+ of the c/m/r instance families, consolidate underutilized nodes after 1 minute, expire any node after 30 days":

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: "KarpenterNodeRole-${CLUSTER_NAME}"   # filled in by envsubst below
  amiSelectorTerms:
    - alias: "al2023@latest"                  # AL2023 latest published EKS-optimized AMI
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"
```

Apply it (using `envsubst` to fill `${CLUSTER_NAME}`):

```bash
envsubst < karpenter-nodepool.yaml | kubectl apply -f -
kubectl get nodepool
kubectl get ec2nodeclass
```

### 6. Test (the canonical "inflate" deployment)

```bash
kubectl create deployment inflate --image=public.ecr.aws/eks-distro/kubernetes/pause:3.7
kubectl set resources deployment inflate --requests=cpu=1
kubectl scale deployment inflate --replicas=5

# watch Karpenter provision instances:
kubectl logs -f -n "${KARPENTER_NAMESPACE}" -l app.kubernetes.io/name=karpenter -c controller
kubectl get nodeclaims
kubectl get nodes -w
```

Then scale back down and watch consolidation:

```bash
kubectl delete deployment inflate
kubectl get nodeclaims -w           # Karpenter terminates the nodes within a minute
```

### 7. Cleanup

```bash
kubectl delete nodepool default
kubectl delete ec2nodeclass default
helm uninstall karpenter --namespace "${KARPENTER_NAMESPACE}"
aws cloudformation delete-stack --stack-name "Karpenter-${CLUSTER_NAME}"
eksctl delete cluster --name "${CLUSTER_NAME}"
```

---

## 5. KEDA (event-driven, scale to zero)

### What is KEDA?

**KEDA** (Kubernetes Event-Driven Autoscaling) is a controller that watches an external source — queue depth, Kafka lag, RabbitMQ messages, Prometheus query, AWS SQS, cron expression, etc. — and scales a Deployment **0..N** based on it. Unlike HPA, KEDA can scale to **zero**.

### A brief history

KEDA started as a Microsoft / Red Hat collaboration in 2019 to fill HPA's biggest gap: scale-to-zero for event-driven workloads. It was donated to the CNCF in 2020 and **graduated** in 2023. The current release at the time of this rewrite is **v2.20.0**, requiring Kubernetes **1.30+**.

### Why it matters

HPA's minimum is 1 replica. For queue consumers, batch workers, and "wake up when there is work" services, you want **zero pods when idle**. KEDA hides itself behind a regular HPA: the `ScaledObject` you create generates an HPA on the fly when there is work, and removes it when the queue drains.

### Common 2026 use cases

- **SQS** consumers that should idle at 0 pods when the queue is empty.
- **Kafka** consumers that scale on consumer-group lag.
- **RabbitMQ** workers.
- Scheduled scale-up (warm a service before a known traffic spike).

### When to use vs not use it

- **Use KEDA** for any worker driven by an external queue / event source.
- **Stick with plain HPA** for HTTP services driven by CPU, memory, or a metric the in-cluster Prometheus already exposes.

### Prerequisites

- EKS cluster on K8s 1.30+.
- `kubectl`, `helm`.
- IAM OIDC provider associated with the cluster (for the IRSA pattern below).
- For the SQS demo: an SQS queue you control + the ARN of an IAM role allowing `sqs:GetQueueAttributes` and `sqs:GetQueueUrl` on that queue.

### 1. Install via Helm (the upstream recommended path)

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda \
  --namespace keda --create-namespace
```

### 2. Verify

```bash
kubectl get pods -n keda
# expect: keda-operator, keda-operator-metrics-apiserver, keda-admission-webhooks
kubectl get crds | grep keda.sh
# expect: scaledobjects.keda.sh, scaledjobs.keda.sh, triggerauthentications.keda.sh, ...
```

### 3. IRSA for KEDA on EKS

The cleanest pattern for AWS scalers is **IRSA on the workload's own ServiceAccount**, then point KEDA at it via a `TriggerAuthentication` with `podIdentity.provider: aws`. The KEDA operator does not need AWS permissions in this pattern — your worker pod does.

Create the IAM policy (`keda-sqs-read.json`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ],
      "Resource": "arn:aws:sqs:us-east-1:<your-account-id>:my-queue"
    }
  ]
}
```

```bash
aws iam create-policy \
  --policy-name KedaSqsReadPolicy \
  --policy-document file://keda-sqs-read.json

eksctl create iamserviceaccount \
  --cluster=dev-cluster \
  --namespace=default \
  --name=worker-sa \
  --attach-policy-arn=arn:aws:iam::<your-account-id>:policy/KedaSqsReadPolicy \
  --override-existing-serviceaccounts \
  --region=us-east-1 \
  --approve
```

### 4. Sample manifest (`keda-scaledobject.yaml`)

The verified upstream pattern for SQS uses a `TriggerAuthentication` with `podIdentity.provider: aws`, which delegates to the ServiceAccount that the target Deployment runs as:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sqs-worker
spec:
  replicas: 0                       # KEDA owns the count; start at 0
  selector:
    matchLabels:
      app: sqs-worker
  template:
    metadata:
      labels:
        app: sqs-worker
    spec:
      serviceAccountName: worker-sa # the IRSA-bound SA from step 3
      containers:
      - name: worker
        image: amazon/aws-cli:2.15.0
        command: ["/bin/sh", "-c"]
        args:
        - >
          while true; do
            aws sqs receive-message --queue-url $QUEUE_URL --region us-east-1 || true;
            sleep 5;
          done
        env:
        - name: QUEUE_URL
          value: "https://sqs.us-east-1.amazonaws.com/<your-account-id>/my-queue"
---
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: keda-aws-sqs-auth
  namespace: default
spec:
  podIdentity:
    provider: aws                   # uses the IRSA on the target's ServiceAccount
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: sqs-worker-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: sqs-worker
  minReplicaCount: 0                # scale to ZERO when idle (this is the point of KEDA)
  maxReplicaCount: 10
  triggers:
  - type: aws-sqs-queue
    authenticationRef:
      name: keda-aws-sqs-auth
    metadata:
      queueURL: https://sqs.us-east-1.amazonaws.com/<your-account-id>/my-queue
      queueLength: "5"              # target: 5 messages per pod
      awsRegion: "us-east-1"
```

### 5. Apply + verify

```bash
kubectl apply -f keda-scaledobject.yaml
kubectl get scaledobject
kubectl describe scaledobject sqs-worker-scaledobject
kubectl get hpa                     # KEDA auto-creates an HPA named keda-hpa-<name>
kubectl get deploy sqs-worker       # should show 0 replicas while queue is empty
```

### 6. Test

Push some messages to your SQS queue and watch the Deployment scale up:

```bash
for i in {1..50}; do
  aws sqs send-message --queue-url https://sqs.us-east-1.amazonaws.com/<your-account-id>/my-queue --message-body "msg-$i" --region us-east-1
done

kubectl get deploy sqs-worker -w
kubectl get pods -l app=sqs-worker -w
```

Drain the queue (or let your worker consume it) and watch the Deployment go back to 0.

### 7. Cleanup

```bash
kubectl delete -f keda-scaledobject.yaml
eksctl delete iamserviceaccount --cluster=dev-cluster --name=worker-sa --namespace=default --region=us-east-1
aws iam delete-policy --policy-arn arn:aws:iam::<your-account-id>:policy/KedaSqsReadPolicy
helm uninstall keda -n keda
kubectl delete namespace keda
```

---

## 6. Decision matrix

| Symptom | Reach for |
|---|---|
| Steady traffic that ebbs and flows with the day | **HPA** (CPU or memory) |
| "I have no idea what to set for requests/limits" | **VPA** (start in `Off` mode, read recommendations) |
| Pods stuck in `Pending` because no node has room — existing ASG-based cluster | **Cluster Autoscaler** |
| Pods stuck in `Pending` — new EKS cluster | **Karpenter** |
| A queue / event-driven worker that should idle at 0 | **KEDA** |
| HTTP service driven by a custom metric (e.g., req/s) | **HPA** with an external/custom metric adapter |

Rule of thumb: **HPA + Karpenter** is the default pair for a new EKS workload in 2026. Add VPA in `Off` mode for visibility. Add KEDA when you have queue-driven services.

## Cleanup (all sections)

```bash
# HPA + nginx demo
kubectl delete -f nginx-deploy-hpa.yaml

# VPA demo (only if VPA controller is installed)
kubectl delete -f vpa-example.yaml --ignore-not-found

# Cluster Autoscaler (only if installed)
helm uninstall cluster-autoscaler -n kube-system 2>/dev/null || true

# Karpenter NodePool (only if Karpenter is installed)
kubectl delete -f karpenter-nodepool.yaml --ignore-not-found

# KEDA ScaledObject (only if KEDA is installed)
kubectl delete -f keda-scaledobject.yaml --ignore-not-found

# Optional: load-generator pod if still hanging around
kubectl delete pod load-generator --ignore-not-found
```
