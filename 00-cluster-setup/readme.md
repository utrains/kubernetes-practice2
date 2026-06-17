# Cluster setup
## Killercoda kubernetes playgrounds
Most of the practice in this repository can be done using kubernetes playgrounds. A precision will be made on labs that should not be performed on Killercoda playgrounds.

### How to use Killercoda kubernetes playgrounds

**Note:** A recommended prerequisite to using Killercoda is to have a Github account. If you are at this level of the class, you should have an account.

1. In your browser, go to the Killercoda official website at [https://killercoda.com/](https://killercoda.com/).
2. Click on Playgrounds.
3. Select the latest Kubernetes playground (Kubernetes 1.32 at the moment of writing this documentation).
4. Sign in using your GitHub account. (You can also sign in using google or your email).
5. Killercoda will authenticate with your GitHub account. Validate if required.
6. Your environment is ready. You can run the command `kubectl get nodes` in the terminal displayed and start practicing.

**Important note**: Use the vi editor in the playground to create your files. Also remember to use `CTRL + Shift + C` to copy and `CTRL + Shift + V` to paste if the CTRL + C does not work.

## Setup EKS cluster using eksctl
There are various ways to setup kubernetes cluster. For this class, we will setup a kubernetes cluster in EKS using eksctl.
This is the production ready cluster we will use throughout the course.

### Prerequisites
Before proceeding, ensure that you have the following prerequisites:

- **AWS Account:** You need to have an AWS account with the appropriate permissions to create and manage EKS clusters.

- **IAM Permissions:** Ensure that your IAM user has sufficient permissions to create an EKS cluster, EC2 instances, and other resources required by EKS. An administrator account works well!

- **AWS CLI:** The AWS Command Line Interface (CLI) must be installed and configured (`aws configure`) with your AWS credentials (access key, secret key, region ...).

### Install kubectl

**kubectl:** is the Kubernetes command-line tool used to interact with the cluster. You can install it following [the instructions here](https://kubernetes.io/docs/tasks/tools/#kubectl).

**Note:** You can use ``choco`` on windows or ``brew`` on Mac

**1. On Windows with choco**
```bash
choco install kubernetes-cli
```

After successful installation, run the following command to verify the version installed:
```bash
kubectl version --client
```

**2. On Mac with Homebrew**

```bash
brew install kubectl
```
or
```bash
brew install kubernetes-cli
```
After successful installation, run the following command to verify the version installed:
```bash
kubectl version --client
```

### Install eksctl

**eksctl** is a simple CLI tool for creating and managing clusters on EKS.
#### Install eksctl on Windows
Open Powershell as administrator and install eksctl using choco with the command:
```bash
choco install eksctl
```

#### Install eksctl on MAC
You can use Homebrew to install eksctl with the command:
 ```bash
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl
```

Refer to the following documentation to install eksctl on your system if the above commands do not work for you: [Link here](https://eksctl.io/installation/)

### Create the cluster in EKS

Use the following command to create a cluster:
```bash
eksctl create cluster --name my-cluster --region us-east-1 --nodegroup-name my-nodes --node-type t3.small --nodes 2 --nodes-min 1 --nodes-max 2
```
**Note:** This command may complete in 10 to 15 minutes depending on your computer and network connection. Be patient and wait till the end of the process

🚨 **WARNING:** If you encounter the following error `Error: invalid version, supported values: 1.19, 1.20, 1.21, 1.22 ...`, you need to upgrade your eksctl version. On Windows, run `choco upgrade eksctl`, or `brew upgrade eksctl` on Mac.

🚨 **WARNING:** If you get an error `AlreadyExistsException: Stack[...]...` in your terminal when launching the cluster, just login to aws and delete the corresponding CloudFormation stack. You might need to forcefully delete it with the option **Force delete the entire stack**.

### Update the Kubeconfig

After creating the cluster, the local kubeconfig file is automatically upated with your cluster information. No need to update the context, you can start to interact with the cluster.

Verify that you can access the cluster. You should see nodes READY.
```bash
kubectl get nodes
```

Note: If the previous throws and error, then update the kubeconfig with the command and retry:

```bash
aws eks update-kubeconfig --region us-east-1 --name my-cluster
```

### Basic commands
| **Command**                                      | **Description**                                                                 |
|--------------------------------------------------|---------------------------------------------------------------------------------|
| `kubectl cluster-info dump`                      | Get details about the cluster (API server, components, etc.).                   |
| `kubectl config view`                            | view the Kubeconfig file                   |
| `kubectl get nodes`                              | List all nodes in the Kubernetes cluster.                                       |
| `kubectl get nodes -o wide`                      | Show more details on node                                  |
| `kubectl get pods`                               | List all pods in the default namespace.                                        |
| `kubectl get pods -o wide`                       | Show more details (e.g., pod IP, node, etc.).                                   |
| `kubectl get deployments`                        | List all deployments in the default namespace.                                  |
| `kubectl get services`                           | List all services in the defaut namespace                                            |
| `kubectl proxy`                                  | Access the Kubernetes cluster dashboard (if set up).                            |

## Cleanup

When done with practice, always delete resources to avoid further charges in the cloud. Run this command only when you are done practicing.

```bash
eksctl delete cluster --name my-cluster --region us-east-1
```

After deleting the cluster, you can verify in CloudFormation that all the stacks related to the cluster creation were successfully deleted.



## (Optional) Cluster Setup with Terraform

🚨 **WARNING:** We will not use this in class. This is just for your information.

The following repository has a terraform code to launch EKS cluster: [Repo link here](https://github.com/utrains/provision-eks-cluster-with-terraform.git)

