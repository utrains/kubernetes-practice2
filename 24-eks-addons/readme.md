# EKS Add-ons: IRSA, Pod Identity, ALB Controller, EBS CSI, EFS CSI, Fargate

These are the AWS-side add-ons that turn a bare EKS cluster into a production-ready one. Every real EKS cluster has some subset of these. In a hiring conversation you should be able to explain what each one does and when you would install it.

This chapter shows the install commands, the manifests, and the AWS-side setup. You need an actual EKS cluster to run these (see chapter 00 for cluster setup).

## What is in this chapter

| Topic | File | What it teaches |
|---|---|---|
| IRSA (IAM Roles for Service Accounts) | `01-irsa-serviceaccount.yaml` | The older, widely-supported way to give a Pod AWS permissions. |
| Pod Identity | `02-pod-identity-association.sh` | The current AWS-native way. Simpler than IRSA. |
| AWS Load Balancer Controller | `03-alb-controller-install.sh` + `04-ingress-alb.yaml` | Lets Ingress manifests create real AWS Application Load Balancers. |
| EBS CSI driver | `05-ebs-storageclass.yaml` + `06-ebs-pvc.yaml` | Dynamic block storage via PVCs. Single-AZ. |
| EFS CSI driver | `07-efs-storageclass.yaml` + `08-efs-pvc.yaml` | Shared NFS filesystem across AZs. Read-write from many Pods at once. |
| Fargate profile | `09-fargate-profile.sh` | Run Pods on serverless VMs. No node group to manage. |

## The mental model (read this first)

An EKS cluster has 3 layers of "how does this Pod get what it needs":

1. **How does the Pod get an IP?** VPC CNI gives every Pod a real VPC IP address. (Installed by default.)
2. **How does the Pod get AWS credentials?** IRSA or Pod Identity. Never hardcode access keys.
3. **How does traffic get to the Pod from outside?** Ingress + ALB Controller.
4. **How does the Pod persist data?** EBS CSI (fast local disk) or EFS CSI (shared).
5. **What runs the Pod?** Managed node group (EC2) or Fargate (serverless).

Everything in this chapter is one of those 5 questions.

## 1. IRSA (IAM Roles for Service Accounts)

IRSA lets a Kubernetes ServiceAccount assume an IAM role. When the Pod runs, the AWS SDK inside it automatically picks up temporary AWS credentials from that role. No secrets, no access keys.

Setup:

```bash
# 1. Enable OIDC provider on your cluster (one-time)
eksctl utils associate-iam-oidc-provider \
  --cluster <cluster-name> \
  --approve

# 2. Create an IAM role that trusts the OIDC provider + the specific ServiceAccount
eksctl create iamserviceaccount \
  --cluster <cluster-name> \
  --namespace default \
  --name s3-reader-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess \
  --approve

# 3. Deploy a Pod using that ServiceAccount
kubectl apply -f 01-irsa-serviceaccount.yaml

# 4. Confirm the Pod has AWS creds
kubectl exec -it s3-reader -- aws s3 ls
```

## 2. Pod Identity (the current AWS-native approach)

Pod Identity replaces IRSA's OIDC dance with a native AWS association API. Simpler to set up. You need the `eks-pod-identity-agent` addon installed.

Setup:

```bash
# 1. Install the addon
aws eks create-addon \
  --cluster-name <cluster-name> \
  --addon-name eks-pod-identity-agent

# 2. Create an IAM role trusted by pods.eks.amazonaws.com
aws iam create-role --role-name pod-s3-reader \
  --assume-role-policy-document file://trust-policy.json
aws iam attach-role-policy --role-name pod-s3-reader \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# 3. Associate the ServiceAccount with the role
./02-pod-identity-association.sh <cluster-name> default s3-reader-sa pod-s3-reader

# 4. Deploy a Pod using that ServiceAccount and confirm AWS creds work
```

## 3. AWS Load Balancer Controller

Vanilla K8s Ingress does nothing on its own. The AWS Load Balancer Controller watches Ingress objects and provisions real AWS Application Load Balancers.

Install:

```bash
bash 03-alb-controller-install.sh <cluster-name> <aws-account-id>
```

Then create an Ingress:

```bash
kubectl apply -f 04-ingress-alb.yaml
kubectl describe ingress alb-demo
# Look for ADDRESS: <ALB DNS name>. That is your real ALB.
```

## 4. EBS CSI driver

EBS is single-AZ block storage. Fast. Perfect for a single-Pod database.

Install:

```bash
aws eks create-addon \
  --cluster-name <cluster-name> \
  --addon-name aws-ebs-csi-driver
```

Use:

```bash
kubectl apply -f 05-ebs-storageclass.yaml   # Defines the StorageClass "gp3"
kubectl apply -f 06-ebs-pvc.yaml            # PVC + Pod using the gp3 StorageClass
```

Trade-off: the Pod is pinned to the AZ where the EBS volume lives. If the node dies and no replacement exists in that AZ, the Pod cannot restart until AWS provisions a new node there.

## 5. EFS CSI driver

EFS is a shared NFS filesystem. Slower than EBS. Perfect for shared uploads, ML model files, or WordPress-style read-heavy content across many replicas.

Install:

```bash
aws eks create-addon \
  --cluster-name <cluster-name> \
  --addon-name aws-efs-csi-driver
```

Prerequisites in AWS:
- Create an EFS filesystem in the same VPC as the cluster.
- Note its file system ID (fs-0a1b2c3d).
- Create a mount target in each AZ subnet.

Use:

```bash
# Edit 07-efs-storageclass.yaml and replace fs-XXXXXXXX with your EFS ID
kubectl apply -f 07-efs-storageclass.yaml
kubectl apply -f 08-efs-pvc.yaml
```

Watch multiple Pods mount the same directory and share files.

## 6. Fargate

Fargate lets Pods run on AWS-managed micro-VMs. No node group. You pay per Pod-second.

When to use: short-lived batch jobs, CronJobs, isolated services where you want a hard VM boundary.

Trade-offs: cold start of 30 to 90 seconds, ~20-30% price premium vs reserved EC2, no DaemonSets, no HostPath volumes, no privileged containers.

Setup:

```bash
bash 09-fargate-profile.sh <cluster-name> team-batch
```

Any Pod in the `team-batch` namespace with matching labels lands on Fargate automatically.

## Docs

- IRSA: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- Pod Identity: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- ALB Controller: https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- EBS CSI: https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html
- EFS CSI: https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html
- Fargate: https://docs.aws.amazon.com/eks/latest/userguide/fargate.html
