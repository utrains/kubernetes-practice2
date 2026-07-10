#!/usr/bin/env bash
# Install the AWS Load Balancer Controller on an EKS cluster.
#
# Usage:
#   ./03-alb-controller-install.sh <cluster-name> <aws-account-id>
# Example:
#   ./03-alb-controller-install.sh my-cluster 123456789012

set -euo pipefail

CLUSTER="${1:?cluster name required}"
ACCOUNT_ID="${2:?aws account id required}"
REGION="${AWS_REGION:-us-east-1}"

# 1. Download and create the IAM policy the controller needs.
POLICY_URL="https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
curl -sSL "$POLICY_URL" -o iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json 2>/dev/null || echo "Policy already exists, continuing"

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"

# 2. Create an IRSA ServiceAccount for the controller.
eksctl create iamserviceaccount \
  --cluster "$CLUSTER" \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn "$POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts

# 3. Add the Helm repo and install the controller chart.
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="$REGION"

# 4. Verify.
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller
kubectl -n kube-system get pods | grep aws-load-balancer

echo
echo "Done. You can now create Ingress objects with:"
echo "  metadata.annotations.kubernetes.io/ingress.class: alb"
echo "and the controller will provision real ALBs for them."
