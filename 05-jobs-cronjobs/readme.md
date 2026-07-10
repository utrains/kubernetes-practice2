# Introduction to Kubernetes Jobs and CronJobs

This covers the basics to get you started with Kubernetes Jobs and CronJobs!

## What Are Jobs and CronJobs?

Jobs run tasks that complete and stop (like backups or data processing). CronJobs are Jobs that run on a schedule (like daily reports).

**Main Use Cases:**
- Batch processing
- Data transformations and migrations
- Database backups
- Sending emails
- Rendering tasks
- Any finite task that needs to run to completion

## Simple Job Example

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: simple-job
spec:
  completions: 1                          # How many Pods should run to completion
  parallelism: 1                          # How many Pods can run in parallel
  backoffLimit: 2                         # Number of retries before job is marked as failed
  ttlSecondsAfterFinished: 50             # Time to keep job after completion (in seconds)
  template:
    spec:
      containers:
      - name: hello
        image: busybox
        command: ["echo", "Hello from my first Job!"]
      restartPolicy: Never
```

To run it and test that the job what executed successfully:
```bash
kubectl apply -f job.yaml
kubectl get jobs
kubectl get pods
kubectl logs <pod-name>
```
The logs should disply the message "**Hello from my first Job!**"
**Note:** The job and the pod associated get deleted 50 seconds after successful execution.

## Simple CronJob Example

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello-cron
spec:
  schedule: "*/1 * * * *"  # Every minute
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            command: ["echo", "Hello from CronJob!"]
          restartPolicy: OnFailure
```

To check it:
```bash
kubectl get cronjobs
kubectl get jobs --watch
```
Note: A new job will be created every minute to perform the task. Do a CTRL C to stop the command.

```bash
kubectl get pods
kubectl get pods --watch
```
Note: Do a CTRL C to stop the command

## Key Things to Know

1. **Jobs**:
   - Run once to completion
   - Good for tasks like database migrations

2. **CronJobs**:
   - Run Jobs on a schedule
   - Good for daily backups or reports

3. **Basic Commands**:
   ```bash
   kubectl get jobs
   kubectl get cronjobs
   kubectl describe job <name>
   kubectl describe cronjob <name>
   kubectl delete job <name>
   kubectl delete cronjob <name>
   ```

4. **Schedule Format**:
   ```
   * * * * *
   │ │ │ │ │
   │ │ │ │ └── Day of week (0-6) (Sunday=0)
   │ │ │ └──── Month (1-12)
   │ │ └────── Day of month (1-31)
   │ └──────── Hour (0-23)
   └────────── Minute (0-59)
   ```

## Common Examples

1. **Database Backup Job**: This is just an example. Don't run it
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-backup
spec:
  template:
    spec:
      containers:
      - name: backup
        image: postgres
        command: ["pg_dump", "-h", "db-service", "-U", "user", "mydb", ">", "/backup/db.sql"]
      restartPolicy: OnFailure
```

2. **Daily Cleanup CronJob**: This is just an example. Don't run it
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: daily-cleanup
spec:
  schedule: "0 0 * * *"  # Midnight daily
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: busybox
            command: ["find", "/data", "-type", "f", "-mtime", "+7", "-delete"]
          restartPolicy: OnFailure
```

## Tips for Beginners

1. Start with simple Jobs before trying CronJobs
2. Always set `restartPolicy` to `Never` or `OnFailure`
3. Check logs with `kubectl logs <pod-name>`
4. Use `kubectl describe job <name>` if something goes wrong
5. Remember CronJobs use UTC time

## Cleanup

```bash
kubectl delete -f simple-job.yaml --ignore-not-found
kubectl delete -f simple-cronjob.yaml --ignore-not-found
```

