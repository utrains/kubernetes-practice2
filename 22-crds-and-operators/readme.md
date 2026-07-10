# CRDs and Operators

## What is a CRD?

A **CustomResourceDefinition** (CRD) is a way to teach Kubernetes a brand-new resource type. Kubernetes ships with built-ins like `Pod`, `Deployment`, `Service`, and `Job`. **CRDs let you add your own** — so the API server learns to accept `Certificate`, `PostgresCluster`, `KafkaTopic`, `Greeting`, or any kind you can dream up.

A CRD by itself is just a schema. It teaches `kubectl` what fields are allowed. It does **not** do anything when you create one of those resources.

## What is an Operator?

An **Operator** is a controller (a piece of code, almost always written in Go) that **watches a CRD and reconciles state**. When you `kubectl apply -f my-certificate.yaml`, the Operator notices the new `Certificate` object and does the actual work — calls Let's Encrypt, stores the cert in a Secret, sets up renewal.

> **CRD = the schema. Operator = the brains.**

## A brief history

The Operator pattern was named and popularized by CoreOS in **2016** with a blog post titled "Introducing Operators". The CRD machinery itself shipped a year earlier as `ThirdPartyResource` (deprecated) and was renamed `CustomResourceDefinition` in K8s 1.7 (2017). The CNCF Operator Framework (Operator SDK, OLM) followed in 2018, donated by Red Hat after the CoreOS acquisition. Today, the Operator pattern is how every non-trivial stateful workload — databases, message brokers, service meshes, certs, secrets — gets managed on Kubernetes.

## Why it matters

An Operator is the only realistic way to package "day-2 ops knowledge" (failover, backups, certificate rotation, version upgrades) as code that runs inside the cluster. Without one, every team rebuilds the same runbooks in Bash.

## Real-world Operators every DevOps engineer sees in 2026

| Operator | What it manages |
|---|---|
| **cert-manager** | TLS certificate lifecycle from Let's Encrypt / ACME / ACM Private CA |
| **postgres-operator** (CloudNativePG, Zalando, Crunchy) | PostgreSQL clusters with backups, failover, read replicas |
| **prometheus-operator** | Prometheus + Alertmanager + ServiceMonitor / PodMonitor ecosystem |
| **external-secrets-operator** | Sync secrets from AWS Secrets Manager / Vault / GCP Secret Manager into K8s Secrets |
| **argocd** (you saw it in chapter 21) | GitOps Application + AppProject |
| **istio / linkerd** | Service mesh resources (`VirtualService`, `DestinationRule`) |

## When to use vs not use an Operator

- **Use one** for any stateful workload (databases, queues, certs, secrets) where rolling your own runbooks is a tax you do not want to pay.
- **Skip it** for stateless apps you can express with a plain `Deployment` + `Service`. Adding a custom Operator just to deploy nginx is over-engineering.

---

## Practice: install cert-manager and use it

cert-manager is the canonical "first Operator everyone installs." We will install it, define a self-signed `Issuer`, request a `Certificate`, and watch cert-manager produce the backing Secret automatically.

> **TODO — install verification needed**
>
> The official cert-manager install pages (`https://cert-manager.io/docs/installation/kubectl/` and `https://cert-manager.io/docs/installation/helm/`) were **not retrievable** during this audit run (every request timed out). The install commands below use the **Helm install method, which is the path cert-manager's docs have officially recommended for several years** — but the **exact current version** could not be confirmed against the upstream release notes during this audit.
>
> Before running this in production, verify the current cert-manager version (the previous chapter pinned `v1.15.3`, which may now be out of date) and any updated Helm install flags at:
>
> - https://cert-manager.io/docs/installation/helm/
> - https://cert-manager.io/docs/installation/kubectl/
> - https://github.com/cert-manager/cert-manager/releases
>
> If the upstream version has moved, update `--version` in the Helm command below.

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

### 1. Install cert-manager via Helm (officially recommended method)

cert-manager's documentation has, for several release cycles, recommended **Helm as the primary install method** for production use — the static `cert-manager.yaml` manifest is still published, but Helm gives you proper upgrade semantics and per-component tuning. We will use Helm here.

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Pin to a specific version. See the TODO above to verify the current stable tag.
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.15.3 \
  --set crds.enabled=true
```

> Notes on the flags:
> - `--set crds.enabled=true` installs the cert-manager CRDs as part of the chart. In older versions this flag was `--set installCRDs=true`; the new name is `crds.enabled`. **TODO**: confirm the spelling against the chart README for the version you pin.
> - You can alternatively install CRDs separately with `kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/<VERSION>/cert-manager.crds.yaml` and then install the chart with `--set crds.enabled=false`.

### 2. Verify

```bash
kubectl get pods -n cert-manager
# expect three pods: cert-manager, cert-manager-cainjector, cert-manager-webhook
kubectl get crds | grep cert-manager
# expect: certificaterequests, certificates, challenges, clusterissuers, issuers, orders
```

### 3. Define a self-signed ClusterIssuer

```bash
kubectl apply -f selfsigned-issuer.yaml
kubectl get clusterissuer
```

### 4. Request a Certificate

```bash
kubectl apply -f demo-certificate.yaml
kubectl get certificate
kubectl describe certificate demo-tls
```

Within a few seconds, cert-manager creates a Secret named `demo-tls` containing `tls.crt` and `tls.key`:

```bash
kubectl get secret demo-tls -o yaml
```

You never wrote that Secret. The Operator did, because you asked for a Certificate.

## Anatomy of a CRD - the `Greeting` example

`custom-crd-greeting.yaml` defines a tiny custom resource called `Greeting`:

```bash
kubectl apply -f custom-crd-greeting.yaml
kubectl get crds | grep greetings
```

Now the API server understands `kind: Greeting`. You can create one:

```yaml
apiVersion: demo.utrains.io/v1
kind: Greeting
metadata:
  name: hello-world
spec:
  message: "Hello, class!"
  language: "en"
```

But **nothing happens** when you apply it — because we never wrote a controller. The object just sits in etcd. That's the point: **a CRD without an Operator is just a schema**.

## How to recognize an Operator in the wild

When you land in a new cluster and see:

```bash
kubectl get all -A
```

...look for:

1. **`kind: <SomethingYouNeverHeardOf>`** in YAML files (e.g., `kind: PostgresCluster`). That tells you a CRD is involved.
2. **A controller deployment in some `*-system` namespace**: `cert-manager`, `prometheus-operator`, `cnpg-system`, `argocd`, `external-secrets`. That's the Operator running.
3. Use `kubectl api-resources --api-group=<group>` to list every kind a given Operator added.

Once you can read an Operator's CRDs + controller deployment, you understand 90% of what it does. The rest is reading its docs.

## Cleanup

```bash
chmod +x cleanup.sh
./cleanup.sh
```

This removes the demo Certificate, the ClusterIssuer, the `greetings` CRD, and uninstalls cert-manager. If you installed via Helm, the script should run `helm uninstall cert-manager -n cert-manager && kubectl delete namespace cert-manager` instead of the kubectl-based uninstall in the v1.15 manifest.
