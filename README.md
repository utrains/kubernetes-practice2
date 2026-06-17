# kubernetes-practice2

Hands-on Kubernetes practice repo for the UTrains DevOps program. **23 numbered chapters** that walk from "what is a pod" through "GitOps with ArgoCD and custom operators." Each chapter is a folder with a `readme.md` and the manifests it references.

For an architectural overview of K8s, see the **Week 20 concepts deck**. This repo is a navigation aid for hands-on practice, not a textbook.

## How to run the practice

Pick the right environment per chapter:

| Environment | Use for | Why |
|---|---|---|
| **Docker Desktop Kubernetes** (or Minikube / Kind) | Chapters **00-10** | Single-node is fine. Fast iteration. No cloud costs. |
| **Killercoda** ([killercoda.com](https://killercoda.com/)) | Quick sandboxes / classroom demos | Free, browser-based, pre-provisioned cluster. Great for chapters 01-10. |
| **EKS** (via `eksctl`) | Chapters **11+** | You need real nodes for DaemonSets, real EBS/EFS for storage, ALB for Ingress, IAM for IRSA. |

Inside each chapter folder, follow the `readme.md` step by step. Run the `## Cleanup` block at the end to keep your cluster (and your AWS bill) tidy.

## Cohort week mapping

This repo is sequenced to match the DevOps program's Kubernetes weeks.

- **Week 20 (K8s Foundations)** - chapters **00-10** (cluster setup -> secrets). Focus: install, basic objects, services + ingress, config + secrets.
- **Week 21 (EKS Migration + K8s Production prep)** - chapters **11-17** (daemonset -> resource-quota). Focus: scheduling, storage, RBAC, network policy, security context, quotas.
- **Week 22 (K8s Production + GitOps)** - chapters **18-22** (maintenance -> CRDs/operators). Focus: cluster ops, Helm, autoscaling, ArgoCD, CRDs.

## Chapter index

| # | Folder | Topic |
|---|---|---|
| 00 | `00-cluster-setup` | Install kubectl + eksctl, create cluster |
| 01 | `01-namespace` | Namespaces |
| 02 | `02-pods` | Pods, QoS classes, probes, priority |
| 03 | `03-replicaset` | ReplicaSets |
| 04 | `04-deployment` | Deployments + rolling-update / recreate strategies |
| 05 | `05-jobs-cronjobs` | Jobs + CronJobs |
| 06 | `06-service` | Services (ClusterIP / NodePort / LoadBalancer / ExternalName) |
| 07 | `07-ingress-and-gateway-api` | Ingress (ALB) + the modern Gateway API |
| 08 | `08-cluster-uis-lens-openlens-k9s` | OpenLens, k9s, Lens Desktop |
| 09 | `09-configmap` | ConfigMaps |
| 10 | `10-secrets` | Secrets |
| 11 | `11-daemonset` | DaemonSets (node-exporter, fluentd) |
| 12 | `12-advanced-scheduling` | nodeSelector, affinity, taints/tolerations |
| 13 | `13-persistent-storage` | EBS + EFS volumes |
| 14 | `14-rbac` | Roles, RoleBindings, ServiceAccounts |
| 15 | `15-network-policy` | NetworkPolicies (allow / deny patterns) |
| 16 | `16-security-context` | securityContext on pods + containers |
| 17 | `17-resource-quota` | ResourceQuotas |
| 18 | `18-cluster-maintenance-and-troubleshooting` | Drains, logs, troubleshooting flow |
| 19 | `19-helm` | Helm: install, upgrade, uninstall |
| 20 | `20-autoscaling-hpa-ca-karpenter-keda` | HPA, VPA, Cluster Autoscaler, Karpenter, KEDA |
| 21 | `21-argocd` | GitOps with ArgoCD |
| 22 | `22-crds-and-operators` | CRDs + Operators (cert-manager demo) |

## What is Kubernetes?

Kubernetes (K8s) is an open-source container orchestration platform that automates the deployment, scaling, and management of containerized applications across a cluster of machines. See the Week 20 deck for the full architectural story.

## K8s architecture (one-liner)

A **control plane** (API server, scheduler, controller manager, etcd) decides what should run; **worker nodes** (kubelet, kube-proxy, container runtime) actually run it. See the Week 20 deck for the diagram and component-by-component walkthrough.

## Kubernetes plugin interfaces

- **CRI** (Container Runtime Interface) - which container runtime runs containers (containerd, CRI-O).
- **CNI** (Container Network Interface) - how pods get IPs and talk to each other (Calico, Cilium, VPC CNI).
- **CSI** (Container Storage Interface) - how external storage attaches to pods (EBS, EFS, NFS).

## K8s cluster setup methods

**For this class** we use **Killercoda** for quick sandboxes and **AWS EKS** for production-style practice. Other options exist for reference:

- **Local/dev**: Minikube, Kind, K3s, MicroK8s, Docker Desktop K8s.
- **Managed**: EKS (AWS), GKE (Google), AKS (Azure), OKE (Oracle), LKE (Linode).
- **Manual / unmanaged**: kubeadm, kubespray, kops.
- **Enterprise distros**: OpenShift, Rancher, Tanzu.

## Interacting with the cluster

- **CLI**: `kubectl`. The default. See chapter 00 for install.
- **Terminal UI**: `k9s`. The modern day-to-day driver. See chapter 08.
- **Desktop UI**: OpenLens (free) or Lens Desktop (paid). See chapter 08.
- **API / IaC**: Helm (chapter 19), ArgoCD (chapter 21), Terraform, client libraries.

## How to use this repo

Chapters are numbered and progressive. In each folder you'll find a `readme.md` plus the YAML manifests it references. Apply manifests with `kubectl apply -f <file>` and follow the cleanup block at the bottom of each chapter when you're done.
