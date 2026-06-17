**Note**: This practice can be done on **Killercoda kubernetes playgrounds**

## The secret 
Secret is just like Configmap but it is used to store sensitive data like private credentials, password,     tokens, secret keys. It does not store data in a plain text form but it stores in an encrypted form using the BASE-64 format. You must always try to improve the security of your Secrets using good practices and advanced security tools such as Vault

### How to create a secret
You can create a secret from the command line
- Using literal values with the option `--from-literal` 
Example:
```bash
kubectl create secret generic db-user-pass1 --from-literal username=admin --from-literal password='S!B\*d$zDsb='
kubectl get secrets
kubectl describe secret db-user-pass1
```
- Using files and directories with the option `--from-file` to pass the filename or the directory
Example:
```bash
echo -n 'admin' > ./username.txt
echo -n 'S!B\*d$zDsb=' > ./password.txt
kubectl create secret generic db-user-pass2 --from-file=username=./username.txt --from-file=password=./password.txt
kubectl get secrets
kubectl describe secret db-user-pass2
```
You can view and decode the value of the username and the password.
```bash
kubectl get secret db-user-pass2 -o jsonpath='{.data.username}' | base64 -d
kubectl get secret db-user-pass2 -o jsonpath='{.data.password}' | base64 -d 
```
- Using a manifest
Convert the username and the password to base64
```bash
echo -n 'devops' | base64
echo -n '1f2d1e2e67df' | base64
```
Create the manifest (`mysecret.yaml`) with the following content:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: ZGV2b3Bz
  password: MWYyZDFlMmU2N2Rm
```

Create and verify the secret
```bash
kubectl create -f mysecret.yaml
kubectl get secrets
kubectl describe secret mysecret
```
### How to use a secret in pod or deployment
- As environment variables for the container using the env or the envFrom parameters

Example: use the content of the file `my-secret-pod.yaml` to create the pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-secret-pod1
spec:
  containers:
    - name: nginx
      image: nginx
      ports:
      - containerPort: 80
      env:
        - name: SECRET_USERNAME # Environment variable name will get the value from the secret
          valueFrom:
            secretKeyRef:
              name: mysecret # Name of the variable from the secret
              key: username
        - name: SECRET_PASSWORD  # Environment variable name will get the value from the secret
          valueFrom:
            secretKeyRef:
              name: mysecret # Name of the variable from the secret
              key: password
```
Create and verify the pod:

```bash
kubectl create -f my-secret-pod.yaml
kubectl get pods
kubectl describe pod my-secret-pod1
kubectl exec -it my-secret-pod1 -- printenv
```

- As a read-only Volume for the application to read

Example: use the content of the file `my-secret-pod-volume.yaml` to create the pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-secret-pod-volume
spec:
  containers:
    - name: nginx
      image: nginx
      volumeMounts:
        - name: secret-volume
          mountPath: /etc/config
          readOnly: true
      ports:
      - containerPort: 80
  volumes:
    - name: secret-volume
      secret:
        secretName: mysecret
```

Create the pod and check that the secret is defined:
```bash
kubectl create -f my-secret-pod-volume.yaml
kubectl exec my-secret-pod-volume -- cat /etc/config/username
kubectl exec my-secret-pod-volume -- cat /etc/config/password
```

Note: If you are using Gitbash in Windows, run the following to check

```bash
kubectl exec -it my-secret-pod-volume -- sh
cat /etc/config/username
cat /etc/config/password
```
Exit from the pod

For more guidelines to manage and improve the security of your Secrets, refer to Good practices for Kubernetes Secrets in the official documentation.

## Cleanup

```bash
kubectl delete -f my-secret-pod.yaml --ignore-not-found
kubectl delete -f my-secret-pod-volume.yaml --ignore-not-found
kubectl delete -f mysecret.yaml --ignore-not-found
```

