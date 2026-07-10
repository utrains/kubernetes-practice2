# Labs-projects

Real-world capstone labs that tie multiple Kubernetes primitives together into a complete deployment. Each lab is opinionated and end-to-end. You start from an empty namespace and finish with a working app you can hit from your browser.

## The labs

### `lab-1-deploy-guestbook-app`
A classic guestbook: a PHP frontend backed by Redis (leader + follower). You practice: `Deployment` for stateless PHP, `StatefulSet` (or Deployment with a single replica) for Redis leader, `Service` for internal DNS, and `Service type=LoadBalancer` for exposing the frontend. Reinforces chapters 04 (deployment), 06 (service), and 09 (configmap).

### `lab-2-deploy-wordpress-with-pvc`
A WordPress site backed by MySQL, both persisting to `PersistentVolumeClaim` backed storage. You practice: `Secret` for the DB password, `PersistentVolumeClaim` for WordPress uploads and MySQL data, `Service` for both tiers. Reinforces chapters 10 (secrets), 13 (persistent-storage), 06 (service), 09 (configmap).

### `pod-breakdown.yaml`
A commented Pod manifest walking through every field. Use it as a reference when you write your own manifests from scratch.

## How to work through these

Do them in order. Each lab assumes you already went through the numbered chapters that map to it. Do NOT jump to Lab 2 before Lab 1: the WordPress lab reuses concepts introduced in the Guestbook lab.

## What comes next

The numbered chapters teach one concept at a time (Pod, Deployment, Service, and so on). The labs bring those concepts together into shippable apps. After finishing Labs 1 and 2, you should be able to describe in a hiring conversation how you would deploy any 3-tier web app on Kubernetes end-to-end.
