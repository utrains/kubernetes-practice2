## Setting up dynamic provisioning in EKS using Amazon EFS to deploy a simple application


#### Prerequisites

- **Amazon EKS Cluster:** Ensure you have a running EKS cluster.
- **AWS CLI:** Install the AWS Command Line Interface.
- **kubectl:** Install the Kubernetes command-line tool.
- **eksctl:** Install `eksctl` for EKS cluster management.
- **Helm:** Install Helm for managing Kubernetes packages.

#### Step 1: Create the Filesystem
1. Get the VPC ID, the subnet IDs and the EKS nodes security group

```bash
# Get VPC and subnet IDs from your EKS cluster
VPC_ID=$(aws eks describe-cluster --name <your-cluster> --region <your region> --query "cluster.resourcesVpcConfig.vpcId" --output text)
SUBNET_IDS=$(aws eks describe-cluster --name <your-cluster> --region <your region> --query "cluster.resourcesVpcConfig.subnetIds" --output text | tr '\t' '\n')
EKS_NODE_SG=$(aws ec2 describe-instances --filters "Name=tag:eks:nodegroup-name,Values=<your-node-group-name>" --query "Reservations[*].Instances[*].SecurityGroups[*].GroupId" --output text --region <your region>)
```
2. Create the security group for EFS using the VPC ID from your cluster

```bash
# Create EFS security group
SG_ID=$(aws ec2 create-security-group --group-name "EFS-SG" --description "EFS for EKS" --vpc-id $VPC_ID --query "GroupId" --output text --region <your region>)
```
3. Open the port 2049 on the security group to allow inbound traffic from EKS nodes

```bash
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 2049 --source-group $EKS_NODE_SG --region <your region>
```
**WARNING:** If you encounter an error like **(InvalidGroupId.Malformed) when calling the AuthorizeSecurityGroupIngress operation: Invalid id: xxxxx**, replace the variable $EKS_NODE_SG directly by the value obtained when you run `echo $EKS_NODE_SG`. The command should then be something like: `aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 2049 --source-group sg-03f2e225be89cbxxx --region <your region>`

4. Create the EFS filesystem 
```bash
# Create EFS filesystem
EFS_ID=$(aws efs create-file-system --creation-token "eks-efs" --tags "Key=Name,Value=EKS-EFS" --output text --query "FileSystemId" --region <your-region>)
```
4. Create mount targets for the filesystem in each subnet of your VPC. Replace ``your region`` with the region you are currently using.
```bash
# Create mount targets in each subnet
for subnet in $SUBNET_IDS; do
  aws efs create-mount-target --file-system-id $EFS_ID --subnet-id $subnet --security-groups $SG_ID --region <your region>
done
```
Now that the filesystem is created with the mount targets, let's install the EFS CSI driver.

#### Step 2: Create a Role  and service account for the EFS CSI Driver
The Amazon EFS Container Storage Interface (CSI) driver requires specific AWS Identity and Access Management (IAM) permissions to manage EFS resources. AWS provides a policy for EFS CSI driver that can be used to create the role.

1. Associate an OIDC provider with your eks cluster

```bash
eksctl utils associate-iam-oidc-provider --cluster my-cluster --region us-east-1 --approve
```
2. Create the IAM Role and Service Account:

Use eksctl to create the IAM role and associate it with a Kubernetes service account:

Copy the command and paste in an editor to replace before running it:

- ``your-cluster-name`` with your EKS cluster name.
- ``your region`` with your region 

```bash
eksctl create iamserviceaccount \
  --name efs-csi-controller-sa \
  --namespace kube-system \
  --cluster your-cluster-name \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy \
  --region us-east-1 \
  --approve
```

#### Step 3: Install the Amazon EFS CSI Driver
Here, you must have Helm installed on your system.

Install the **EFS CSI driver** using **Helm**:

```bash
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update
helm install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  --namespace kube-system \
  --set controller.serviceAccount.create=false \
  --set controller.serviceAccount.name=efs-csi-controller-sa
```
This command installs the EFS CSI driver and configures it to use the previously created service account.

Verify that the pods are running
```bash
kubectl get pods -n kube-system
```

#### Step 4: Create the storageClass for dynamic provisioning

Define a StorageClass that references your EFS file system:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: your-efs-filesystem-id
  directoryPerms: "700"
```

Replace **your-efs-filesystem-id** with the **FileSystemId** obtained earlier (echo $EFS_ID). Apply this configuration:

```bash
kubectl apply -f storageclass.yaml
kubectl get storageclass
```
#### Step 5: Create a PVC and a deployment 

Create a file for the PVC and the deployment (`efs-pvc-deployment.yaml`). The content should look like:

```yaml
### pvc definition
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: efs-pvc
spec:
  accessModes:
    - ReadWriteMany  # RWX for many nodes
  resources:
    requests:
      storage: 5Gi  # size (EFS is elastic thus adjust automatically)
  storageClassName: efs-sc
---
### deployment def
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: app
        image: nginx
        volumeMounts:
        - name: efs-volume
          mountPath: /data
      volumes:
      - name: efs-volume
        persistentVolumeClaim:
          claimName: efs-pvc
---
### service def
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 80
```
Apply the file to the cluster and verify

```bash
kubectl apply -f efs-pvc-deployment.yaml
kubetl get pvc
kubectl get pods -o wide
```
Check Shared Data Across all the Pods

```bash
# Test shared storage (write to one pod, read from another)
kubectl exec -it <pod1-name> -- sh -c "echo 'Hello EFS' > /data/test.txt"
kubectl exec -it <pod2-name> -- sh
# in the pod, display the content of the file modified by pod 1
cat /data/test.txt
exit
```
All pods should see the same file test.txt since they share the EFS volume.

## 8. Cleanup (When Needed)
```bash
kubectl delete -f efs-pvc-deployment.yaml
kubectl delete -f efs-storage-class.yaml
# delete the mount targets
aws efs describe-mount-targets --file-system-id $EFS_ID --query "MountTargets[*].MountTargetId" --output table --region <your-region>
# delete each mount target
aws efs delete-mount-target --mount-target-id <mount-target1-id> --region <your-region>
aws efs delete-mount-target --mount-target-id <mount-target2-id> --region <your-region>
aws efs delete-mount-target --mount-target-id <mount-target3-id> --region <your-region>
...
aws efs delete-file-system --file-system-id $EFS_ID --region <your-region>
eksctl delete iamserviceaccount --name efs-csi-controller-sa --namespace kube-system --cluster your-cluster-name --region <your-region>
## delete EFS security group
aws ec2 delete-security-group --group-id $SG_ID --region <your-region>
```
Delele your cluster when done practicing.

## Notes For production:

- Add resource requests/limits
- Configure pod anti-affinity
- Enable EFS backup (AWS Backup)
- Restrict IAM permissions to specific EFS resources

This provides a shared, persistent filesystem accessible by all pods simultaneously.


