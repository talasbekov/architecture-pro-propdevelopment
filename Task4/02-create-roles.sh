#!/usr/bin/env bash
set -euo pipefail

# В режиме --render манифест выводится без обращения к кластеру.
render() {
cat <<'YAML'
apiVersion: v1
kind: Namespace
metadata:
  name: propdevelopment
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
  - apiGroups: [""]
    resources: ["configmaps", "endpoints", "events", "namespaces", "nodes", "persistentvolumeclaims", "persistentvolumes", "pods", "services"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps", "batch", "networking.k8s.io"]
    resources: ["daemonsets", "deployments", "replicasets", "statefulsets", "cronjobs", "jobs", "ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-developer
rules:
  - apiGroups: [""]
    resources: ["configmaps", "events", "persistentvolumeclaims", "pods", "pods/log", "services"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps", "batch", "networking.k8s.io"]
    resources: ["deployments", "replicasets", "statefulsets", "cronjobs", "jobs", "ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-operator
rules:
  - apiGroups: [""]
    resources: ["namespaces", "nodes", "persistentvolumes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["configmaps", "endpoints", "events", "persistentvolumeclaims", "pods", "pods/log", "services"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps", "batch", "networking.k8s.io"]
    resources: ["daemonsets", "deployments", "replicasets", "statefulsets", "cronjobs", "jobs", "ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-secret-reader
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    resourceNames: ["application-tls", "integration-credentials"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: limited-security-admin
rules:
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["configmaps", "events", "pods", "pods/log", "serviceaccounts"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: limited-security-admin-psa
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["namespaces"]
    resourceNames: ["propdevelopment"]
    verbs: ["patch"]
YAML
}

if [[ "${1:-}" == "--render" ]]; then
  render
elif [[ $# -eq 0 ]]; then
  render | kubectl apply -f -
else
  echo "Использование: $0 [--render]" >&2
  exit 2
fi
