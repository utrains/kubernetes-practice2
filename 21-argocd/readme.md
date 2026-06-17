# ArgoCD - GitOps for Kubernetes

## What is ArgoCD?

**ArgoCD is a GitOps controller** that lives inside your Kubernetes cluster and continuously reconciles cluster state to match what's declared in a Git repository. Every change to your cluster goes through Git: commit -> PR -> merge -> ArgoCD applies it. There is no more `kubectl apply` from someone's laptop.

## Why it matters

- **Every change is a git commit + PR review.** You get code-review on infrastructure changes for free.
- **Audit trail by design.** Git history *is* your change log.
- **Drift detection.** If someone bypasses the process and runs `kubectl edit`, ArgoCD will either warn or revert (depending on your sync policy).
- **Disaster recovery.** Lose the cluster? Apply the bootstrap manifest, point ArgoCD at the repo, the cluster rebuilds itself.

## Install on EKS

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for the pods to come up:

```bash
kubectl get pods -n argocd -w
```

## Access the UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open `https://localhost:8080` (accept the self-signed cert).

Username: `admin`. Get the initial password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

(You should rotate this password from the UI right after login.)

## The 3 concepts

ArgoCD's whole model is three CRDs:

- **Application** - a CRD that says "watch THIS Git repo, THIS path, sync to THIS namespace on THIS cluster." This is the main building block.
- **AppProject** - groups Applications for RBAC. "The platform team can deploy to any namespace; the payments team can only deploy to `payments-*`."
- **Sync policy** - lives on the Application. Two flavors:
  - **Manual** - you (or a CI job) click "Sync" in the UI to apply pending changes.
  - **Automated** - ArgoCD reconciles on every commit. With `selfHeal: true`, it also reverts manual edits. With `prune: true`, it deletes resources that are removed from Git.

## Practice

The included `argocd-application.yaml` deploys the `04-deployment/` chapter of THIS repo via ArgoCD.

```bash
kubectl apply -f argocd-application.yaml
kubectl get applications -n argocd
```

Watch in the UI: you should see `nginx-demo` appear, sync, and become `Healthy / Synced`.

Then make a change in Git: bump the `replicas` in `04-deployment/01-nginx-deployment.yaml`, commit, push. Within ~3 minutes (the default sync poll interval) ArgoCD applies the change. You can also click **Refresh** in the UI to force an immediate check.

## Cleanup

Use the included `cleanup.sh`:

```bash
chmod +x cleanup.sh
./cleanup.sh
```

It removes the Application, uninstalls ArgoCD, and deletes the namespace.
