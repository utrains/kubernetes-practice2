# Security Context

Security Context is how Kubernetes lets you lock down what a Pod (or a single container inside it) is allowed to do at the Linux level.

Running a container as the root user means every process inside that container has root privileges. If an attacker gets inside, they can install packages, change system time, mount volumes, and touch anything the kernel exposes. Security Context is the switch you flip to prevent that.

## The 7 options that matter

- **runAsNonRoot**: kubelet refuses to start the Pod if the image tries to run as UID 0. Hard block.
- **runAsUser**: run every process inside the container as a specific user ID (like 1000).
- **runAsGroup**: run every process with a specific group ID.
- **fsGroup**: when the container mounts a volume, files created there get this group ID. Important for shared PVCs.
- **privileged**: run the container in privileged mode (equivalent to root on the host). Almost always what you do NOT want. A privileged container can load kernel modules, access all devices, and bypass most security features.
- **capabilities**: Linux capabilities are the pieces that make up root. Drop ALL and add back only what you need. A web server only needs `NET_BIND_SERVICE` to bind port 80.
- **readOnlyRootFileSystem**: mount `/` read-only. An attacker cannot drop malware into `/tmp` or `/usr/local/bin`. If your app writes temp files, mount an `emptyDir` volume at that path.

## Where you apply it

Two levels:

1. **Pod-level `securityContext`** (under `spec.securityContext`): applies to every container in the Pod. Use this for `runAsNonRoot`, `runAsUser`, `fsGroup`.
2. **Container-level `securityContext`** (under `spec.containers[].securityContext`): overrides the Pod-level setting for that one container. Use this for `capabilities`, `allowPrivilegeEscalation`, `readOnlyRootFilesystem`.

If a value is set at both levels, container-level wins.

## The 5 example manifests in this folder

| File | What it teaches |
|---|---|
| `privileged-pod.yaml` | A container running in privileged mode. This is the anti-pattern. Look at it to know what NOT to do. |
| `pod-run-as-non-root.yaml` | Enforces `runAsNonRoot: true`. If the image tries to run as UID 0, the Pod fails to start. Test with an image that expects root and watch it fail. |
| `pod-change-time.yaml` | Demonstrates a Pod trying to change the system clock. Without `CAP_SYS_TIME` capability it cannot. Use to prove capabilities matter. |
| `pod-remove-chown.yaml` | Drops `CAP_CHOWN`. The container cannot change file ownership even as root. |
| `secure-pod.yaml` | The hardened baseline: non-root, read-only root FS, drop ALL capabilities. Use this as the template for every new production Pod. |

## Walkthrough

Work through the files in this order:

```bash
# 1. See what a privileged Pod looks like (this is the wrong way, for reference)
kubectl apply -f privileged-pod.yaml
kubectl exec -it privileged-pod -- id
# Expect: uid=0(root). This is what we want to prevent.
kubectl delete -f privileged-pod.yaml

# 2. Prevent root
kubectl apply -f pod-run-as-non-root.yaml
kubectl exec -it non-root-pod -- id
# Expect: uid=1000. Non-root.
kubectl delete -f pod-run-as-non-root.yaml

# 3. Drop capabilities and try to change the clock
kubectl apply -f pod-change-time.yaml
kubectl exec -it change-time-pod -- date --set="2020-01-01"
# Expect: operation not permitted, because CAP_SYS_TIME was dropped.
kubectl delete -f pod-change-time.yaml

# 4. Drop CAP_CHOWN and try to chown a file
kubectl apply -f pod-remove-chown.yaml
kubectl exec -it chown-pod -- chown 65534 /tmp/testfile
# Expect: operation not permitted.
kubectl delete -f pod-remove-chown.yaml

# 5. The hardened baseline: apply and inspect
kubectl apply -f secure-pod.yaml
kubectl describe pod secure-pod
# Expect: runAsNonRoot: true, readOnlyRootFilesystem: true, capabilities.drop: [ALL].
```

## Real-world anchors

- **Capital One 2019**: an SSRF vulnerability plus an over-privileged IAM role leaked 100M records. If the Pod that hit the metadata service had been running with `readOnlyRootFilesystem` and dropped capabilities, the attacker still needs to write files to persist. Security Context does not fix a bad IAM policy but it makes exploitation much harder.
- **Container escapes in the wild**: nearly every publicized container escape (Dirty Pipe, runc CVEs) starts with a privileged container or one with `CAP_SYS_ADMIN`. Dropping capabilities eliminates that whole class.

## The 3 rules that stick

1. **Every production Pod runs `runAsNonRoot: true` and `readOnlyRootFilesystem: true`.** No exceptions.
2. **Drop ALL Linux capabilities**, then add back only what the app needs. Web server: `NET_BIND_SERVICE`. That is it.
3. **Never use `privileged: true`** unless you are writing a CNI plugin, a CSI driver, or a monitoring agent that legitimately needs host access.

## Cluster-wide enforcement

Security Context protects one Pod. Developers can forget to add it. To enforce security-context rules at the namespace level so bad Pods are rejected at creation, use **PodSecurityAdmission** with labels on the namespace:

```bash
kubectl label namespace my-app \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

The 3 PSA levels:
- **privileged**: allow everything. Use only for kube-system and infra add-ons that legitimately need root.
- **baseline**: block the obvious risks (privileged containers, hostNetwork, hostPID).
- **restricted**: hardened default. Non-root, no capabilities except `NET_BIND_SERVICE`, no privilege escalation. This is what you want for team namespaces in a shared cluster.

## Docs

- kubernetes.io/docs/tasks/configure-pod-container/security-context/
- kubernetes.io/docs/concepts/security/pod-security-admission/

## Cleanup

```bash
kubectl delete -f pod-change-time.yaml --ignore-not-found
kubectl delete -f pod-remove-chown.yaml --ignore-not-found
kubectl delete -f pod-run-as-non-root.yaml --ignore-not-found
kubectl delete -f privileged-pod.yaml --ignore-not-found
kubectl delete -f secure-pod.yaml --ignore-not-found
```
