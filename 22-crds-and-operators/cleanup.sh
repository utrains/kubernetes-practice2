#!/usr/bin/env bash
kubectl delete certificate demo-tls --ignore-not-found
kubectl delete clusterissuer selfsigned-issuer --ignore-not-found
kubectl delete crd greetings.demo.utrains.io --ignore-not-found
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml --ignore-not-found
