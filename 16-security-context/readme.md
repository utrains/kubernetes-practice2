## Security Context
Security context implies applying security at the pod or the container level.

When you run a container as the root user, all processes running inside that container will have the same root privileges. This is not safe

When defining the security context, we can use options like
- **runAsNonRoot** to prevent processes from running as the root user 
- **runAsUser** to run processes with a specific user ID
- **runAsGroup** to run processes with a specific group ID
- **fsGroup** , especially when using volumes
- **Privileged** to run privileged containers (which can perform tasks on the host parameters)
- **Capabilities** (to grant or restrict some permissions)
- **readOnlyRootFileSystem** to mount the container's root file system as read-only

**Example:** Open the various maifest in this folder to go through some examples of pods with security context.

## Cleanup

```bash
kubectl delete -f pod-change-time.yaml --ignore-not-found
kubectl delete -f pod-remove-chown.yaml --ignore-not-found
kubectl delete -f pod-run-as-non-root.yaml --ignore-not-found
kubectl delete -f privileged-pod.yaml --ignore-not-found
kubectl delete -f secure-pod.yaml --ignore-not-found
```
