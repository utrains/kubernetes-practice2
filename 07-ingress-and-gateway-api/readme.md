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

The Kubernetes Ingress API has been around since 1.1 and is showing its age. The community's answer is the **Gateway API**, which became **GA in K8s 1.31 (mid-2024)**.

### What's different

Instead of one overloaded `Ingress` resource, Gateway API splits responsibility across **3 resources**:

- **GatewayClass** — defines a class of gateways (e.g., "AWS ALB"). Maintained by the platform team.
- **Gateway** — an actual listener (ports, protocols, TLS). Maintained by the cluster admin or app team lead.
- **HTTPRoute** (and `TCPRoute`, `GRPCRoute`, etc.) — the routing rules. Owned by app developers.

This separation gives you **better support for header-based routing, weighted traffic splitting (canaries / blue-green), and multi-tenancy** out of the box — without vendor-specific annotations.

### On EKS

Install via the **`aws-load-balancer-controller` v2.7+**, which now implements **both** the Ingress API and the Gateway API. You do not need a separate controller. Once installed, you can mix Ingress and Gateway resources in the same cluster while you migrate.

### Minimal HTTPRoute example

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app1-route
spec:
  parentRefs:
    - name: my-gateway          # the Gateway this route attaches to
  hostnames:
    - app1.example.com
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: app1-service
          port: 80
```

### When to choose Ingress vs Gateway API in 2026

- **Stick with Ingress** for simple host/path routing where you don't need traffic splitting or multiple teams sharing a single load balancer. It's still fully supported and the docs / examples are everywhere.
- **Move to Gateway API** when you need traffic-splitting (canaries, A/B), header-based routing, mTLS, or a clear platform-team / app-team split (multi-tenancy). New greenfield platforms in 2026 should default to Gateway API.

## Cleanup

```bash
kubectl delete -f ingress.yaml
kubectl delete -f app1.yaml
kubectl delete -f app2.yaml
# Optional: uninstall the ALB controller if you are done with EKS practice
helm uninstall aws-load-balancer-controller -n kube-system
```
