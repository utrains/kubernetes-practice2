#!/usr/bin/env bash
kubectl delete application nginx-demo -n argocd --ignore-not-found
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --ignore-not-found
kubectl delete namespace argocd --ignore-not-found
