# CRDs and Operators

## What is a CRD?

A **CustomResourceDefinition** (CRD) is a way to teach Kubernetes a brand-new resource type. Kubernetes ships with built-ins like `Pod`, `Deployment`, `Service`, and `Job`. **CRDs let you add your own** - so the API server learns to accept `Certificate`, `PostgresCluster`, `KafkaTopic`, `Greeting`, or any kind you can dream up.

A CRD by itself is just a schema. It teaches `kubectl` what fields are allowed. It does **not** do anything when you create one of those resources.

## What is an Operator?

An **Operator** is a controller (a piece of code, almost always written in Go) that **watches a CRD and reconciles state**. When you `kubectl apply -f my-certificate.yaml`, the Operator notices the new `Certificate` object and does the actual work - calls Let's Encrypt, stores the cert in a Secret, sets up renewal.

> **CRD = the schema. Operator = the brains.**

## Real-world Operators every DevOps engineer sees in 2026

| Operator | What it manages |
|---|---|
| **cert-manager** | TLS certificate lifecycle from Let's Encrypt / ACME / ACM Private CA |
| **postgres-operator** (CloudNativePG, Zalando, Crunchy) | PostgreSQL clusters with backups, failover, read replicas |
| **prometheus-operator** | Prometheus + Alertmanager + ServiceMonitor / PodMonitor ecosystem |
| **external-secrets-operator** | Sync secrets from AWS Secrets Manager / Vault / GCP Secret Manager into K8s Secrets |
| **argocd** (you saw it in chapter 21) | GitOps Application + AppProject |
| **istio / linkerd** | Service mesh resources (`VirtualService`, `DestinationRule`) |

## Practice: install cert-manager and use it

cert-manager is the canonical "first Operator everyone installs." We'll install it, define a self-signed `Issuer`, request a `Certificate`, and watch cert-manager produce the backing Secret automatically.

### 1. Install

```bash
chmod +x cert-manager-install.sh
./cert-manager-install.sh
```

This applies the official `cert-manager.yaml` (which is itself a giant manifest containing the CRDs + the controller Deployment).

Verify:

```bash
kubectl get pods -n cert-manager
kubectl get crds | grep cert-manager
```

You should see three `cert-manager` CRDs: `Issuer`, `ClusterIssuer`, `Certificate`, plus a few more.

### 2. Define a self-signed ClusterIssuer

```bash
kubectl apply -f selfsigned-issuer.yaml
```

### 3. Request a Certificate

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

But **nothing happens** when you apply it - because we never wrote a controller. The object just sits in etcd. That's the point: **a CRD without an Operator is just a schema**.

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

This removes the demo Certificate, the ClusterIssuer, the `greetings` CRD, and uninstalls cert-manager.
