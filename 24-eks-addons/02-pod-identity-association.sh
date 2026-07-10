#!/usr/bin/env bash
# Associate a Kubernetes ServiceAccount with an IAM role using EKS Pod Identity.
#
# Usage:
#   ./02-pod-identity-association.sh <cluster-name> <namespace> <sa-name> <role-name>
# Example:
#   ./02-pod-identity-association.sh my-cluster default s3-reader-sa pod-s3-reader

set -euo pipefail

CLUSTER="${1:?cluster name required}"
NAMESPACE="${2:?namespace required}"
SA_NAME="${3:?serviceaccount name required}"
ROLE_NAME="${4:?IAM role name required}"

# 1. Make sure the eks-pod-identity-agent addon is installed.
aws eks describe-addon \
  --cluster-name "$CLUSTER" \
  --addon-name eks-pod-identity-agent \
  > /dev/null 2>&1 || \
aws eks create-addon \
  --cluster-name "$CLUSTER" \
  --addon-name eks-pod-identity-agent

# 2. Create the ServiceAccount in the cluster if it does not exist.
kubectl create serviceaccount "$SA_NAME" -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# 3. Get the IAM role ARN.
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

# 4. Create the Pod Identity association.
aws eks create-pod-identity-association \
  --cluster-name "$CLUSTER" \
  --namespace "$NAMESPACE" \
  --service-account "$SA_NAME" \
  --role-arn "$ROLE_ARN"

echo "Done. Pods in namespace $NAMESPACE using serviceAccountName: $SA_NAME"
echo "will now assume role $ROLE_NAME."
