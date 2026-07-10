## What is kubernetes?
Kubernetes (K8s) is an open-source container orchestration platform that help to automate the deployment, scaling, and management of containerized applications.

## Why use kubernetes?
- Companies moved from **physical servers → VMs → containers → Kubernetes** to make applications run faster, more efficient (optimize resources usage), and easier to manage at scale.
- companies are moving from **monolithic** app to **microservices** architecture increasing the usage of containers and the need to efficiently manage them in various environments.
## Kubernetes architecture
Kubernetes has a **Control plane** - **Worker** architecture:
### Control plane:
The control plane manages the worker nodes and the pods in the cluster. It contains:
- **API Server** – Entry point for commands (talks to users & other parts).
- **Scheduler** – Decides where to run new containers.
- **Controller Manager** – Handles tasks like scaling & failures.
- **etcd** – Stores all cluster data (like a database).
- **Cloud controller manager**  - ( for cloud cluster. this is in case kubernetes needs to create ressources in the cloud )

### Worker node (nodes):

- **Kubelet** – Talks to the control plane to run and manage containers.
- **Container Runtime** – Runs containers (e.g., Docker, containerd).
- **Kube Proxy** – Manages network communication between containers.

NB: control plane node also has **kubelet, kube-proxy and container runtime** because it runs some system pods 
### Pods
Smallest unit in K8s, holds one or more containers.

## Kubernetes Plugins or Kubernetes Interfaces
   - **CRI** → Manages containers
   - **CNI** → Handles networking
   - **CSI** → Manages storage.

1. CRI (Container Runtime Interface)
- Enables Kubernetes to use different container runtimes (e.g., containerd, CRI-O, Docker).
- Defines how Kubernetes interacts with the runtime to manage containers.
- Decouples Kubernetes from specific runtimes for flexibility.

2. CNI (Container Network Interface)
- Standard for configuring networking in Kubernetes pods.
- Plugins (e.g., Calico, Flannel, Cilium) handle IP allocation, routing, and network policies.
- Ensures pods can communicate within and outside the cluster.

3. CSI (Container Storage Interface)
- Allows Kubernetes to integrate with external storage systems (e.g., AWS EBS, NFS, Ceph).
- Standardizes how storage is provisioned, attached, and mounted to pods.
- Enables dynamic volume provisioning and snapshots.

## Key features of kubernetes
- **Autoscaling** – Increases or decreases containers based on traffic.
- **Self-Healing** – Restarts failed containers, replaces unhealthy ones.
- **Load Balancing** – Distributes traffic across containers for efficiency.
- **Rolling Updates & Rollbacks** – Updates apps without downtime and rolls back if needed (high availability)
- **Service Discovery** – Finds and connects services without manual setup (using IP adress or DNS).
- **Storage Management** – Supports local, cloud, or network storage easily.
- **Multi-Cloud & Hybrid Support** – Runs across AWS, Google Cloud, Azure, and on-prem.
- **Automated Deployments** – Uses YAML files for easy and repeatable deployments.
- **Secrets & Config Management** – Manages configuration and sensitive data securely.
- **Resource Optimization** – Ensures best use of CPU, memory, and storage (automatic bin packing)
- **production Support**– Can be used for production environments

## K8s cluster setup methods
**Note:** In this class, we will use kubernetes playgrounds on Killercoda for testing and deploy our production cluster in AWS EKS. The following are just for more information on various methods available.

### For learning and local development/testing
- **Minikube** – Runs a single-node K8s cluster on your laptop. You can check the [official documentation](https://minikube.sigs.k8s.io/docs/) for minikube just to get more information.
- **Kind (Kubernetes in Docker)** – Uses Docker to run lightweight K8s clusters. 
- **Kubernetes on Docker Desktop** – If you already have Docker Desktop on Mac or Windows, turn on the built-in Kubernetes toggle in Settings > Kubernetes. You get a single-node cluster with `kubectl` already wired up. Zero extra install.
- **K3s** – A lightweight Kubernetes distribution for low-resource systems.
- **MicroK8s** – A lightweight K8s version from Canonical.
- **Killercoda playgroungs for Kubernetes**: Killercoda is a platform where you get instant access to a real Linux or Kubernetes environment ready to use. **Note: In the cluster setup for this class, you will learn how to use it. We will use it for some practices**

### For production
#### 1. Manual setup (unmanaged)
- using Kubeadm
- Using kubespray
- Using Kops
- From scratch (complex)

#### 2.  Cloud based (managed)
- Amazon EKS – Kubernetes on AWS. **Note: This is what we will use in this class**
- Google GKE – Kubernetes on Google Cloud.
- Azure AKS – Kubernetes on Microsoft Azure.
- Oracle OKE - Kubernetes on Oracle
- LKE - Kubernetes on Linode
- ...

#### 3. Enterprise Kubernetes (K8s distributions)
- Openshift – Red Hat’s enterprise Kubernetes with extra features.
- Rancher – Multi-cluster Kubernetes management.
- Tanzu - vSphere Tanzu Kubernetes Grid (TKG)
- ...

## Interacting with cluster
- **Command Line Interface (CLI)**: using `kubectl` commands
- **User Interface (UI)**: using the native **K8s Dashboard** or tools like **Lens**
- **Kubernetes API**: Using programmatical access (ex. with python scripts, terraform codes etc.)


## How to use this repo
The repo is organized and ordered for you to practice the concepts progressively.

In each folder, you will find a readme file to help you understand the concept and practice.

**Note**: All the files mentioned in the **readme** can be directly found in the same folder. Just use the content of those files if no other specification is given.

## Chapter index

**25 numbered chapters** that walk from "what is a pod" through "GitOps, custom operators, broken-Pod triage, and EKS-specific add-ons." Click any chapter name to jump to its walkthrough.

| # | Chapter | What you will practice |
|---|---|---|
| 00 | [Cluster setup](./00-cluster-setup/readme.md) | Install `kubectl`, `eksctl`, and `helm`. Pick your practice environment: a free Killercoda sandbox, a local Docker Desktop / Kind cluster, or a real AWS EKS cluster stood up with `eksctl`. |
| 01 | [Namespace](./01-namespace/readme.md) | Create isolated namespaces, switch context between them, and see how the same object name can live in multiple namespaces without conflict. |
| 02 | [Pods](./02-pods/readme.md) | Deploy Pods from YAML and from `kubectl run`. Set QoS classes (BestEffort, Burstable, Guaranteed). Wire up liveness, readiness, and startup probes. Assign PriorityClasses so critical Pods never get evicted. |
| 03 | [ReplicaSet](./03-replicaset/readme.md) | Create a ReplicaSet, watch it heal Pod deletions, and understand why you almost never write one directly (a Deployment creates one for you). |
| 04 | [Deployment](./04-deployment/readme.md) | Roll out a new image version with zero downtime using the RollingUpdate strategy, then flip to Recreate and see the outage. Roll back to a previous revision with `kubectl rollout undo`. |
| 05 | [Jobs + CronJobs](./05-jobs-cronjobs/readme.md) | Run one-off batch work with a Job. Schedule recurring work every minute with a CronJob. Set `backoffLimit` and `activeDeadlineSeconds` for safety. |
| 06 | [Service](./06-service/readme.md) | Expose Pods with all four Service types: ClusterIP (internal), NodePort (node port on every node), LoadBalancer (cloud LB), ExternalName (DNS alias to an external host). |
| 07 | [Ingress + Gateway API](./07-ingress-and-gateway-api/readme.md) | Route traffic to many Services behind one Ingress with path-based rules. Then compare to the modern Gateway API and see when to reach for each. |
| 08 | [Cluster UIs: Lens, OpenLens, k9s](./08-cluster-uis-lens-openlens-k9s/readme.md) | Install the terminal UI `k9s` and the desktop UIs OpenLens (free) or Lens Desktop. Understand when a GUI beats `kubectl` in day-to-day work. |
| 09 | [ConfigMap](./09-configmap/readme.md) | Store non-secret configuration as key/value data. Consume it inside a Pod as environment variables, command-line args, or mounted files. |
| 10 | [Secrets](./10-secrets/readme.md) | Store passwords and API tokens. Mount them into Pods as environment variables or files. Understand what base64 encoding does and does NOT protect you from. |
| 11 | [DaemonSet](./11-daemonset/readme.md) | Run one Pod per node with a DaemonSet: a node-exporter for Prometheus metrics and a Fluentd log collector. |
| 12 | [Advanced scheduling](./12-advanced-scheduling/readme.md) | Control which node a Pod lands on with nodeSelector, node affinity, Pod affinity / anti-affinity, taints and tolerations, and topology spread constraints. |
| 13 | [Persistent storage](./13-persistent-storage/readme.md) | Provision persistent storage with PersistentVolume, PersistentVolumeClaim, and StorageClass. See the difference between static and dynamic provisioning. |
| 14 | [RBAC](./14-rbac/readme.md) | Create a ServiceAccount, bind it to a Role or ClusterRole, and prove that Pods using that SA can only do what the Role allows. |
| 15 | [Network policy](./15-network-policy/readme.md) | Start from the default-allow-everything state, apply a default-deny policy, then explicitly allow just the traffic your app needs. |
| 16 | [Security context](./16-security-context/readme.md) | Harden a Pod: run as non-root, mount root filesystem read-only, drop ALL Linux capabilities, block privilege escalation. Optional cluster-wide guardrail with PodSecurityAdmission. |
| 17 | [Resource quota](./17-resource-quota/readme.md) | Cap total CPU / memory / pod count per namespace with ResourceQuota. Cap per-Pod usage and set defaults with LimitRange. |
| 18 | [Cluster maintenance + troubleshooting](./18-cluster-maintenance-and-troubleshooting/readme.md) | Cordon and drain a node without dropping traffic. Back up etcd. Walk through EKS maintenance scenarios: rolling worker upgrades, Kubernetes version upgrades, PDBs for high availability. |
| 19 | [Helm](./19-helm/readme.md) | Install, upgrade, roll back, and uninstall Helm charts. Understand the `values.yaml` override pattern. |
| 20 | [Autoscaling: HPA / CA / Karpenter / KEDA](./20-autoscaling-hpa-ca-karpenter-keda/readme.md) | Scale Pods horizontally on CPU with HPA. Scale Pods vertically with VPA in recommendation mode. Scale nodes with Cluster Autoscaler and the modern replacement Karpenter. Scale on custom events (SQS depth, Kafka lag) with KEDA. |
| 21 | [ArgoCD (GitOps)](./21-argocd/readme.md) | Install ArgoCD, wire an Application to a git repo, watch sync + drift detection, and then structure many apps with an AppProject and the App-of-Apps pattern. |
| 22 | [CRDs + Operators](./22-crds-and-operators/readme.md) | Install cert-manager (a real-world Operator) and use its CRDs (Issuer, Certificate) to auto-provision TLS certs. Recognize the CRD + Operator pattern that every serious K8s tool ships as. |
| 23 | [Troubleshooting: broken Pods](./23-troubleshooting-broken-pods/readme.md) | Diagnose 5 pre-broken Pod manifests using the `describe → events → logs → exec` playbook. Covers ImagePullBackOff, CreateContainerConfigError, CrashLoopBackOff, OOMKilled, and the Service-selector-mismatch trap. |
| 24 | [EKS add-ons](./24-eks-addons/readme.md) | AWS-native practice: IRSA + Pod Identity for Pod IAM, AWS Load Balancer Controller for real ALBs, EBS CSI for block storage, EFS CSI for shared filesystems, Fargate for serverless Pods. |
| — | [Labs-projects](./Labs-projects/README.md) | Capstone labs that combine many concepts into one end-to-end app: PHP + Redis Guestbook, WordPress + MySQL with persistent volumes. |

## Cohort week mapping

This repo is sequenced to match the DevOps program's Kubernetes weeks.

- **Week 20 (K8s Foundations)** - chapters **00-10** (cluster setup -> secrets). Focus: install, basic objects, services + ingress, config + secrets.
- **Week 21 (EKS Migration + K8s Production prep)** - chapters **11-17** (daemonset -> resource-quota). Focus: scheduling, storage, RBAC, network policy, security context, quotas.
- **Week 22 (K8s Production + GitOps)** - chapters **18-22** (maintenance -> CRDs/operators). Focus: cluster ops, Helm, autoscaling, ArgoCD, CRDs.
- **Cross-week production practice** - chapters **23-24**. Broken-Pod triage playbook (23) and EKS-specific add-ons: IRSA, Pod Identity, ALB Controller, EBS/EFS CSI, Fargate (24).
