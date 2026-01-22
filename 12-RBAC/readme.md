## Role Based Access Control (RBAC) in a kubernetes cluster

### Definitions
- **Role Based Access Control** in kubernetes is an authorization method to access the cluster resources based on the roles of users within your organization.
The RBAC is setup by cluster administrators to control access to the cluster and cluster resources.

- **A role** contains a set of rules that represent a set of permissions in a namespace
- **A RoleBinding** is used to bind a Role to a user or a group of users.
- **A ClusterRole** is a role used to define a set of permissions on the entire cluster or on cluster-wide resources.
- **A ClusterRoleBinding** is used to bind a ClusterRole to a user or group of users

### How to setup RBAC in k8s
To set up RBAC, we need to identify the who, the what and the rules:
- Who (the subject like user, group of users, service account)
- What (resources like pods, services, deployments, ...)
- rules (what action is allowed and what action is not allowed)

### Steps
- create a namespace
- create a role
- create a rolebinding
- create the subject (user, group or service account)
- Create the config file for the subject to assume the role for cluster access
- verify that the subjet only have access to the permissions set in the role

### Practice

We have a new user called Paul in dev team and we need to give him access to the cluster resources. As an administrator, setup RBAC using a service account to allow Paul to list and create pods and services in the dev namespace.

1. Create the namespace, the role the service account and the role binding `rbac-sa.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    kubernetes.io/metadata.name: dev
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: create-list-pod-services
  namespace: "dev" 
rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["create", "list", "delete"]
    #  - apiGroups: ["apps"]
    #    resources: ["deployment"]
    #    verbs: ["create", "get", "update", "list", "delete", "watch", "patch"]
    #  - apiGroups: ["rbac.authorization.k8s.io"]
    #    resources: ["clusterroles", "clusterrolebindings"]
    #    verbs: ["create", "get", "list", "watch"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dev-sa
  namespace: "dev"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: create-list-pod-services-rb
  namespace: "dev"
subjects:
  - kind: ServiceAccount
    name: dev-sa
    namespace: dev
roleRef:
  kind: Role
  name: create-list-pod-services
  apiGroup: rbac.authorization.k8s.io
```
Apply this file to the cluster to create the resources

```bash
kubectl apply -f rbac-sa.yaml
```
2. Test

Here we will do a simple test to verify that users that will be associated with this service account will only have access to the defined resources.

```bash
kubectl get pods -n dev --as=system:serviceaccount:dev:dev-sa
```
Now, remove the namespace to verify that you cannot access the pods resources in other namespaces:

```bash
kubectl get pods --as=system:serviceaccount:dev:dev-sa
```
Expected result: You should have a **Forbidden error**.

Test with other resources like services, deployments etc

3. Recommendation

In the company, to create access for a new user, a kubeconfig file like `config-template.yaml` will be generated and securely sent to the user. 

The user will add it to his local kubeconfig file in `.kube/` and update the kubeconfig with the command before starting to interact with the cluster.

```bash
aws eks update-kubeconfig --region region-code --name cluster-name
```


**Note: The goal here is just for you to have an overview of why and how RBAC can be set in clusters to enhance security.**

