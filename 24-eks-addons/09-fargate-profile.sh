#!/usr/bin/env bash
# Create a Fargate profile so Pods in the specified namespace run on Fargate micro-VMs.
#
# Usage:
#   ./09-fargate-profile.sh <cluster-name> <namespace>
# Example:
#   ./09-fargate-profile.sh my-cluster team-batch

set -euo pipefail

CLUSTER="${1:?cluster name required}"
NAMESPACE="${2:?namespace required}"

# Get the private subnet IDs for the cluster (Fargate only runs on private subnets).
SUBNETS=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.subnetIds' --output text | tr '\t' ',')

# Create the Fargate profile.
eksctl create fargateprofile \
  --cluster "$CLUSTER" \
  --name "fargate-$NAMESPACE" \
  --namespace "$NAMESPACE"

echo
echo "Done. Any Pod in namespace $NAMESPACE will now schedule onto a Fargate micro-VM."
echo
echo "Verify with:"
echo "  kubectl get nodes -o wide"
echo "You will see nodes with names like fargate-ip-10-0-1-23.ec2.internal."
