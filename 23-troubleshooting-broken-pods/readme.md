# Troubleshooting: Broken Pod Triage

Every K8s hiring conversation includes some version of "walk me through debugging a stuck Pod." Reading about it is not the same as doing it. This chapter gives you 5 pre-broken Pod manifests. You apply each one, diagnose the failure from `kubectl describe` + `kubectl logs`, and fix it. Solutions are at the bottom of this README.

## The debug playbook (memorize the ORDER, not the syntax)

```bash
# 1. What is the STATUS?
kubectl get pods

# 2. Read the Events at the bottom of describe. This tells you WHAT the cluster tried and failed to do.
kubectl describe pod <name>

# 3. Read the container logs. Add --previous if the container already restarted.
kubectl logs <name>
kubectl logs <name> --previous

# 4. Get inside the container filesystem. Look at config, env vars, mounts.
kubectl exec -it <name> -- sh

# 5. Isolate network vs app failure by hitting the app locally.
kubectl port-forward <name> 8080:80

# 6. Is the Pod resource-starved?
kubectl top pod <name>
```

You will not use all 6 steps every time. Steps 1, 2, and 3 solve 80% of real Pod failures. Steps 4, 5, 6 handle the tricky ones.

## The 5 scenarios

Work through them in order. Each YAML in this folder is intentionally broken. Apply it, diagnose the STATUS, use the playbook to find the root cause, then fix the YAML and re-apply.

### Setup

```bash
kubectl create namespace triage
kubectl config set-context --current --namespace=triage
```

### Scenario 1: broken-01-image-typo.yaml

Apply it. Watch `kubectl get pods`. What STATUS shows up?

<details>
<summary>Solution</summary>

STATUS: `ImagePullBackOff` or `ErrImagePull`.

`kubectl describe pod broken-01` shows in Events: `Failed to pull image "nginx:1.27.999": ...manifest for nginx:1.27.999 not found`.

Root cause: the image tag `1.27.999` does not exist. The image name is fine, the tag is a typo.

Fix: change `image: nginx:1.27.999` to `image: nginx:1.27` in the manifest, then `kubectl apply -f` again.
</details>

### Scenario 2: broken-02-missing-configmap.yaml

Apply it. What STATUS shows up?

<details>
<summary>Solution</summary>

STATUS: `CreateContainerConfigError`.

`kubectl describe pod broken-02` shows in Events: `configmap "app-config" not found`.

Root cause: the Pod's environment references a ConfigMap called `app-config` in the `triage` namespace, but that ConfigMap does not exist.

Fix (option A): create the missing ConfigMap.
```bash
kubectl create configmap app-config --from-literal=APP_MODE=production
```

Fix (option B): remove the ConfigMap reference from the manifest if the app does not need it.

The interview follow-up: "what if the ConfigMap exists but a KEY inside it is missing?" Then STATUS is still `CreateContainerConfigError` and the Events say `couldn't find key <key> in ConfigMap`.
</details>

### Scenario 3: broken-03-wrong-probe-port.yaml

Apply it. Watch STATUS over the next 60 seconds. What happens?

<details>
<summary>Solution</summary>

STATUS cycles: `Running` briefly, then `CrashLoopBackOff`.

`kubectl describe pod broken-03` shows in Events: `Liveness probe failed: dial tcp 10.x.x.x:9999: connect: connection refused`. Kubelet keeps killing and restarting the container.

Root cause: the liveness probe is set to hit port `9999` but nginx listens on port `80`. Every liveness check fails. Kubelet restarts the container.

Fix: change `port: 9999` to `port: 80` in the livenessProbe stanza.

The interview follow-up: "why does the Pod show 1 restart, then 2, then 3, then 5, then wait longer between restarts?" Because kubelet uses exponential backoff on CrashLoopBackOff. First retry after 10s, then 20, 40, 80, up to 5 minutes.
</details>

### Scenario 4: broken-04-oom.yaml

Apply it. Wait 30 seconds. What STATUS shows up?

<details>
<summary>Solution</summary>

STATUS: `OOMKilled` (visible in `kubectl describe` under Last State).

`kubectl describe pod broken-04` shows: `Last State: Terminated, Reason: OOMKilled`.

Root cause: the container has a memory limit of `20Mi` but runs a program that allocates 100Mi. The Linux kernel OOM killer terminates it.

Fix (option A): raise the memory limit to `256Mi` or whatever the app actually needs (verify with `kubectl top pod`).

Fix (option B): fix the app to use less memory. Usually the app is fine and the limit was set too low.

The interview follow-up: "how do you find the right memory limit?" Run the app for a week without limits (or with generous limits), watch actual usage with `kubectl top`, then set limits at roughly p99 of observed usage plus 20% buffer. Or use VPA in recommendation-only mode.
</details>

### Scenario 5: broken-05-service-selector-mismatch.yaml

This one has TWO objects: a Deployment and a Service. Apply the file. Both Pods start Running. Then try `kubectl port-forward svc/web 8080:80` and hit `curl http://localhost:8080`. What happens?

<details>
<summary>Solution</summary>

`curl` hangs or returns nothing. Everything LOOKS fine: Pods Running, Service exists.

The debug move: `kubectl get endpoints web`. Output shows `ENDPOINTS: <none>`.

Root cause: the Service's `selector: { app: webserver }` does not match the Deployment's Pod labels (`app: web`). The Service has zero Pods to route to. Every request times out because the Service has no backends.

Fix: change either the Deployment's `metadata.labels.app` or the Service's `selector.app` so they match.

This is the single most common "everything looks fine but nothing works" bug in K8s. Always check `kubectl get endpoints` when a Service is not routing.
</details>

## STATUS to root-cause cheat sheet

| STATUS | First thing to check | Common root cause |
|---|---|---|
| `ImagePullBackOff` / `ErrImagePull` | image name + tag | typo, private registry with no imagePullSecret, wrong architecture |
| `CreateContainerConfigError` | Events in describe | missing ConfigMap / Secret / key |
| `CrashLoopBackOff` | `logs --previous` | app crashes on start (env var missing, config file missing, DB not reachable) |
| `OOMKilled` | describe Last State | memory limit too tight for actual usage |
| `Pending` | Events in describe | insufficient CPU/memory in cluster, unschedulable due to taints, PVC not bound |
| `Running` but Service returns nothing | `kubectl get endpoints <svc>` | Service selector does not match Pod labels |
| `Terminating` and stuck | `kubectl get pod <name> -o yaml` | finalizer blocking deletion; force delete with `--grace-period=0 --force` (use with care) |

## What comes next

Once you can diagnose these 5 in your sleep, you have the muscle memory for 80% of real K8s incidents in production. The remaining 20% are cluster-level failures (kubelet crashed, CNI broken, control plane unreachable). Chapter 18 (cluster-maintenance-and-troubleshooting) covers those.

## Cleanup

```bash
kubectl delete namespace triage
```
