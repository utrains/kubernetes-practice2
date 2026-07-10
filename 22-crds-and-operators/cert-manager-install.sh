#!/usr/bin/env bash
# Install cert-manager via the official manifest.
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml
# Wait for pods.
kubectl -n cert-manager wait --for=condition=Ready pod --all --timeout=120s
