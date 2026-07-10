**Note:** This lab should be done in the **EKS cluster**
# The ingress resource
Ingress exposes HTTP and HTTPS routes from outside the cluster to services within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.

To use the ingress resource, you must configure an ingress controller such as ingress-nginx, HAproxy, AWS Load balancer

## Why Use Ingress?
- Reduces Cost – Uses a single entry point instead of multiple LoadBalancers.
- Supports Routing – Directs traffic based on URL paths or hostnames.
- Enables HTTPS (SSL) – Provides security for web applications.
- Load Balancing – Distributes traffic across multiple services.

## How Ingress Works
1. User sends a request to myapp.com/api.
2. Request reaches Ingress (single entry point).
3. Ingress checks rules and routes traffic.
4. Request is sent to the correct service inside the cluster.
5. The response is sent back to the user.

## Practice

### Prerequisites
The following prerequisites are necessary to complete this Lb.
- **Domain:** create a hosted zone in route 53 with your domain (e.g., example.com). If you already have one, you can use it.
- **ACM Certificate**: Create ACM certificate for your domain and subdomains (e.g., *.example.com). If you already have it, you can skip this step
- **Cluster:** Deploy a cluster with eksctl
```bash
 eksctl create cluster --name dev-cluster --region us-east-1 --nodegroup-name dev-nodes --node-type t3.small --nodes 2 --nodes-min 1 --nodes-max 2
```
- **kubeconfig Updated**: update your kubeconfig to access the cluster
```bash
aws eks update-kubeconfig --region us-east-1 --name dev-cluster
```

### Enable ingress controller in EKS

1. create an IAM OIDC provider for your cluster (if not already created):
```bash
eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster dev-cluster --approve
```
2. Create an IAM policy for the ALB controller:

- Download the policy document

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json
```
- Create the policy with the policy file downloaded

```bash 
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
```

3. Create an IAM role and ServiceAccount for the controller: Do not forget to replace ``your-account-id`` with your aws account ID 
```bash
eksctl create iamserviceaccount --cluster=dev-cluster --namespace=kube-system --name=aws-load-balancer-controller --attach-policy-arn=arn:aws:iam::<your-account-id>:policy/AWSLoadBalancerControllerIAMPolicy --override-existing-serviceaccounts --region us-east-1 --approve
```

4. Install the ALB controller using Helm:

- Add the Helm repository
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

- Install the controller
```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller --namespace kube-system --set clusterName=dev-cluster --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller
```
### Create sample applications 

(Let's call them app1 and app2). 

Create files for each app:

App 1 manifest
```yaml
#app1.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app1
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app1-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: app1
```

App 2 manifest
```yaml
#app2.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: app2
        image: httpd
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app2-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: app2
```
Ingress resource manifest. Add your certificate ARN in the annotations section, replace the host with your actual subdomain names before applying the manifest.

**Note on `spec.ingressClassName: alb`:** This is the post-K8s-1.22 syntax. The older `kubernetes.io/ingress.class: alb` annotation still works for backward compatibility, but it is deprecated. Use the modern `spec.ingressClassName` field on any K8s cluster running 1.22 or newer (which includes every supported EKS version in 2026).

```yaml
#ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-app-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn:  # Add the arn number of your ACM certification here
spec:
  ingressClassName: alb                    # MODERN (K8s 1.22+); replaces the old kubernetes.io/ingress.class annotation
  rules:
  - host: app1.awscertif.site     # subdomain for app1 
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.awscertif.site     # subdomain for app2 
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

**Important notes:**
•  Replace ``your-region``, ``your-cluster-name``, ``your-account-id``, and ``your-acm-certificate-arn`` with your actual values
•  Make sure you have a valid SSL certificate in AWS Certificate Manager (ACM) for your domain
•  Update the hostnames in the ingress configuration to match your actual domain names

```bash
kubectl apply -f app1.yaml 
kubectl apply -f app2.yaml 
kubectl apply -f ingress.yaml
kubectl get pods -n kube-system | grep "aws-load-balancer-controller"
kubectl get ingress
kubectl get svc
```
After applying the manifests in the cluster, you need to create/update the DNS records in Route 53 to point your domains to the ingress address (you can get this after the ingress is created)
```bash
kubectl get ingress
```
# Test 

Try to hit all different sub domain for your app in the browser
```bash
app1.yourdomain.com
app2.yoursomain.com 
```

## Gateway API: the modern successor to Ingress

### What is Gateway API?

The Kubernetes Ingress API has been around since 1.1 and is showing its age. The community's answer is the **Gateway API**, a set of CRDs (`GatewayClass`, `Gateway`, `HTTPRoute`, `TCPRoute`, `GRPCRoute`, ...) that replace and extend Ingress.

### A brief history

Ingress shipped in K8s 1.1 (2015). It worked, but every controller layered vendor-specific annotations (`nginx.ingress.kubernetes.io/...`, `alb.ingress.kubernetes.io/...`) to expose features the spec did not cover. By 2019, traffic-splitting, header-based routing, and multi-team ownership of one load balancer were universally requested and universally implemented as annotation soup. SIG-Network started the Gateway API project that year. The core resources reached **GA (v1.0) in October 2023**, and the current standard channel as of this rewrite is **v1.5.0**.

### Why it matters

Gateway API splits responsibility across **3 resources** so each one has a clear owner:

- **GatewayClass** — defines a class of gateways (e.g., "AWS ALB"). Installed by the platform team / cluster admin.
- **Gateway** — an actual listener (ports, protocols, TLS). Owned by the cluster admin or app team lead.
- **HTTPRoute** (or `TCPRoute`, `GRPCRoute`, etc.) — the routing rules. Owned by app developers.

This gives you **header-based routing, weighted traffic splitting (canaries / blue-green), and cross-namespace routing** in the spec itself, with no controller-specific annotations.

### When to use vs not use it

- **Stick with Ingress** for simple host/path routing on a single team's load balancer. It is still fully supported, and tooling / examples are everywhere.
- **Move to Gateway API** when you need traffic-splitting, header-based routing, gRPC, or a clear platform-team / app-team split. New greenfield platforms in 2026 should default to Gateway API.

---

## Practice: Gateway API on EKS with the AWS Load Balancer Controller

### Prerequisites

- Same EKS cluster, ACM cert, Route 53 hosted zone, and kubeconfig as the Ingress section above.
- **`aws-load-balancer-controller` >= v2.14.0** installed (the controller you installed earlier already implements Gateway API as long as it is on v2.14+). The L7 ALB Gateway path requires v2.14.0. The L4 NLB Gateway path requires v2.13.0+.
- `kubectl` and `helm` available.

Verify the controller version:

```bash
kubectl get deploy -n kube-system aws-load-balancer-controller \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
# expect:  public.ecr.aws/eks/aws-load-balancer-controller:v2.14.x  (or newer)
```

If it is older, upgrade with Helm before continuing:

```bash
helm repo update eks
helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=dev-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### 1. Install the Gateway API CRDs

The Gateway API CRDs are **not** part of stock Kubernetes — you install them yourself. Install the standard channel from upstream:

```bash
kubectl apply --server-side -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
```

> The standard channel includes the GA resources: `GatewayClass`, `Gateway`, `HTTPRoute`, `GRPCRoute`, and `ReferenceGrant`. If you also need `TCPRoute`, `UDPRoute`, or `TLSRoute` for L4 use cases, install the experimental channel instead (`experimental-install.yaml` from the same release).

Verify:

```bash
kubectl get crds | grep gateway.networking.k8s.io
# expect: gatewayclasses, gateways, grpcroutes, httproutes, referencegrants
```

### 2. Install the AWS LBC Gateway API CRDs

The AWS Load Balancer Controller adds three of its own CRDs that are used to configure ALB-specific behavior on Gateways: `LoadBalancerConfiguration`, `TargetGroupConfiguration`, and `ListenerRuleConfiguration`.

```bash
kubectl apply -f \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml
```

Verify the controller picked them up — restart the controller deployment so it re-detects the CRDs, then check the logs:

```bash
kubectl rollout restart deploy/aws-load-balancer-controller -n kube-system
kubectl logs -n kube-system deploy/aws-load-balancer-controller | grep -i gateway
```

You should see lines indicating the `ALBGatewayAPI` and `NLBGatewayAPI` controllers are enabled.

### 3. IAM permissions

The IAM policy you attached to the `aws-load-balancer-controller` ServiceAccount earlier (from `iam_policy.json` on the v2.11.0 release) already covers most ALB / NLB actions. For Gateway API, AWS recommends pulling the **latest** policy from the controller release matching your installed version:

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.0/docs/install/iam_policy.json
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicyV2_14 \
  --policy-document file://iam_policy.json
```

Then update the IRSA role to point at the new policy ARN (or attach it alongside the old one). If you originally created the role with `eksctl create iamserviceaccount`, the easiest path is to re-run the same command with `--override-existing-serviceaccounts` and the new policy ARN.

### 4. Sample workload

Reuse `app1` from the Ingress section above. If you cleaned up, re-apply:

```bash
kubectl apply -f app1.yaml
```

### 5. The Gateway + HTTPRoute manifests

```yaml
# gatewayclass.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: alb
spec:
  controllerName: gateway.k8s.aws/alb        # The AWS LBC's ALB Gateway controller
```

```yaml
# gateway.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: default
spec:
  gatewayClassName: alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same                          # only Routes from the same namespace can attach
```

```yaml
# httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app1-route
  namespace: default
spec:
  parentRefs:
    - name: my-gateway                        # attach to the Gateway above
  hostnames:
    - app1.awscertif.site                     # replace with your subdomain
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: app1-service
          port: 80
```

### 6. Apply + verify

```bash
kubectl apply -f gatewayclass.yaml
kubectl apply -f gateway.yaml
kubectl apply -f httproute.yaml

kubectl get gatewayclass
kubectl get gateway
kubectl get httproute
```

The Gateway will eventually show an address (the provisioned ALB DNS name) in the `ADDRESS` column. Describe it for status conditions:

```bash
kubectl describe gateway my-gateway
# look for "Accepted: True" and "Programmed: True" under Listener Status
```

Then create / update the Route 53 record so `app1.awscertif.site` points to the ALB DNS shown by `kubectl get gateway my-gateway`.

### 7. Test

```bash
curl http://app1.awscertif.site
# or open it in a browser
```

### 8. Cleanup

```bash
kubectl delete -f httproute.yaml
kubectl delete -f gateway.yaml
kubectl delete -f gatewayclass.yaml
kubectl delete -f app1.yaml

# Optional: remove the Gateway API CRDs (only do this if nothing else uses them)
kubectl delete -f \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/config/crd/gateway/gateway-crds.yaml
kubectl delete -f \
  https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml

# Optional: uninstall the ALB controller if you are done with the cluster
helm uninstall aws-load-balancer-controller -n kube-system
```
