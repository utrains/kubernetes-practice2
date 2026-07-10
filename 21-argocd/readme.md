# ArgoCD - GitOps for Kubernetes

## What is ArgoCD?

**ArgoCD is a GitOps controller** that lives inside your Kubernetes cluster and continuously reconciles cluster state to match what is declared in a Git repository. Every change to your cluster goes through Git: commit -> PR -> merge -> ArgoCD applies it. There is no more `kubectl apply` from someone's laptop.

## A brief history

Argo CD was created at Intuit in 2018 to solve the "who pushed what, when, why?" problem they had operating dozens of Kubernetes clusters. Intuit donated the broader Argo project (Argo Workflows, Argo CD, Argo Events, Argo Rollouts) to the CNCF in 2020. Argo CD **graduated** at the CNCF in **December 2022**, joining the ranks of fully production-ready CNCF projects. It is now the dominant GitOps controller for Kubernetes, with Flux as its main peer.

## Why it matters

- **Every change is a git commit + PR review.** You get code-review on infrastructure changes for free.
- **Audit trail by design.** Git history *is* your change log.
- **Drift detection.** If someone bypasses the process and runs `kubectl edit`, ArgoCD will either warn or revert (depending on your sync policy).
- **Disaster recovery.** Lose the cluster? Apply the bootstrap manifest, point ArgoCD at the repo, the cluster rebuilds itself.

## When to use vs not use it

- **Use ArgoCD** as soon as more than one person, or one CI pipeline, applies changes to the same cluster. Day-2 ops without it gets ugly fast.
- **Skip it** for throwaway clusters and single-developer playgrounds — the operational overhead of running another controller is not worth it.

---

## Practice: install ArgoCD on EKS

> **TODO — install verification needed**
>
> The official Argo CD install pages (`https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/` and `https://argo-cd.readthedocs.io/en/stable/getting_started/`) were **not retrievable** during this audit run (the read-the-docs site timed out repeatedly). The install commands below are the ones that have worked in this course in prior sessions, but **before relying on them in production**, please verify the latest recommended install method (especially the recommended pinned chart version and any new IRSA setup) at:
>
> - https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/
> - https://argo-cd.readthedocs.io/en/stable/getting_started/
> - The Helm chart at https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd

### Prerequisites

- An EKS cluster:

```bash
eksctl create cluster --name dev-cluster --region us-east-1 \
  --nodegroup-name dev-nodes --node-type t3.small \
  --nodes 2 --nodes-min 1 --nodes-max 2
```

- kubeconfig pointed at it:

```bash
aws eks update-kubeconfig --region us-east-1 --name dev-cluster
```

- `kubectl` and `helm` installed locally.
- A Git repository ArgoCD can read (public, or with credentials configured).

### Option A — install from the upstream `install.yaml` (quickest)

This is the path documented in the upstream "getting started" tutorial. It applies a single large manifest containing the CRDs, the `argocd` namespace's RBAC, and the controller deployments.

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

> The `stable` ref always points at the latest GA release. In a production setup you should **pin to a specific tag** (e.g., `v2.13.0`) so upgrades are an explicit action, not a side effect of re-applying a manifest. Replace `stable` with the tag you want. **TODO**: confirm the current GA tag at https://github.com/argoproj/argo-cd/releases.

Wait for the pods to come up:

```bash
kubectl get pods -n argocd -w
# expect 7 pods running: argocd-application-controller, argocd-applicationset-controller,
# argocd-dex-server, argocd-notifications-controller, argocd-redis, argocd-repo-server,
# argocd-server
```

### Option B — install via the official Helm chart (recommended for EKS)

The community-maintained `argo-cd` Helm chart (`argoproj/argo-helm`) is the path most EKS shops use because it lets you set IRSA annotations, replicas, HA flags, and an ingress in one place.

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace
```

> **TODO**: verify the latest chart version (and whether the chart name has changed) at https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd. Pin with `--version X.Y.Z` for production.

### IRSA for ArgoCD (optional, but production-grade on EKS)

ArgoCD itself usually does not need AWS API access — it talks to Git and the in-cluster Kubernetes API. But two real-world cases need IRSA:

1. **Git repo on AWS CodeCommit** — the `argocd-repo-server` ServiceAccount needs an IAM role allowing `codecommit:GitPull`.
2. **Helm charts in a private ECR registry** — the `argocd-repo-server` ServiceAccount needs `ecr:GetAuthorizationToken` and `ecr:BatchGetImage` on the relevant repos.

Pattern (replace the policy ARN with one that grants exactly what you need):

```bash
eksctl create iamserviceaccount \
  --cluster=dev-cluster \
  --namespace=argocd \
  --name=argocd-repo-server \
  --attach-policy-arn=arn:aws:iam::<your-account-id>:policy/ArgoCDRepoServerPolicy \
  --override-existing-serviceaccounts \
  --region=us-east-1 \
  --approve

# Then either restart the repo-server, or — if you installed via Helm —
# re-run `helm upgrade` with --set repoServer.serviceAccount.create=false
# and --set repoServer.serviceAccount.name=argocd-repo-server
kubectl rollout restart deploy/argocd-repo-server -n argocd
```

> **TODO**: confirm the exact ServiceAccount name(s) for the version you install (in older chart versions it was `argocd-repo-server`; the install.yaml uses the same name). Cross-check at https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/.

---

## Access the UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open `https://localhost:8080` (accept the self-signed cert).

Username: `admin`. Get the initial password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d ; echo
```

Rotate this password from the UI immediately after first login (Settings -> Accounts).

---

## The 3 concepts

ArgoCD's whole model is three CRDs:

- **Application** — a CRD that says "watch THIS Git repo, THIS path, sync to THIS namespace on THIS cluster." This is the main building block.
- **AppProject** — groups Applications for RBAC. "The platform team can deploy to any namespace; the payments team can only deploy to `payments-*`."
- **Sync policy** — lives on the Application. Two flavors:
  - **Manual** — you (or a CI job) click "Sync" in the UI (or run `argocd app sync`) to apply pending changes.
  - **Automated** — ArgoCD reconciles on every commit. With `selfHeal: true`, it also reverts manual edits. With `prune: true`, it deletes resources that are removed from Git.

## Sample Application manifest

The included `argocd-application.yaml` deploys the `04-deployment/` chapter of THIS repo via ArgoCD.

```bash
kubectl apply -f argocd-application.yaml
kubectl get applications -n argocd
```

Watch in the UI: you should see `nginx-demo` appear, sync, and become `Healthy / Synced`.

## Test

Make a change in Git: bump the `replicas` in `04-deployment/01-nginx-deployment.yaml`, commit, push. Within ~3 minutes (the default sync poll interval) ArgoCD applies the change. You can also click **Refresh** in the UI to force an immediate check.

## Cleanup

Use the included `cleanup.sh`:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

It removes the Application, uninstalls ArgoCD, and deletes the namespace.

If you installed via Helm instead of the raw manifest, also run:

```bash
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```
