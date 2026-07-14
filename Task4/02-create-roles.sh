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
    resources: ["configmaps", "endpoints", "events", "persistentvolumeclaims", "pods", "pods/log", "services"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps", "batch", "networking.k8s.io"]
    resources: ["daemonsets", "deployments", "replicasets", "statefulsets", "cronjobs", "jobs", "ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-operator-cluster-reader
rules:
  - apiGroups: [""]
    resources: ["namespaces", "nodes", "persistentvolumes"]
    verbs: ["get", "list", "watch"]
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
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: propdevelopment-psa-labels-only
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["UPDATE"]
        resources: ["namespaces"]
  matchConditions:
    - name: propdevelopment-only
      expression: object.metadata.name == 'propdevelopment'
  validations:
    - expression: >-
        object.metadata.name == oldObject.metadata.name &&
        object.metadata.generateName == oldObject.metadata.generateName &&
        object.metadata.namespace == oldObject.metadata.namespace &&
        object.metadata.annotations == oldObject.metadata.annotations &&
        object.metadata.finalizers == oldObject.metadata.finalizers &&
        object.metadata.ownerReferences == oldObject.metadata.ownerReferences &&
        object.metadata.deletionTimestamp == oldObject.metadata.deletionTimestamp &&
        object.metadata.deletionGracePeriodSeconds == oldObject.metadata.deletionGracePeriodSeconds &&
        object.metadata.labels.filter(k, v, !(k in [
          'pod-security.kubernetes.io/enforce',
          'pod-security.kubernetes.io/enforce-version',
          'pod-security.kubernetes.io/audit',
          'pod-security.kubernetes.io/audit-version',
          'pod-security.kubernetes.io/warn',
          'pod-security.kubernetes.io/warn-version'
        ])) == oldObject.metadata.labels.filter(k, v, !(k in [
          'pod-security.kubernetes.io/enforce',
          'pod-security.kubernetes.io/enforce-version',
          'pod-security.kubernetes.io/audit',
          'pod-security.kubernetes.io/audit-version',
          'pod-security.kubernetes.io/warn',
          'pod-security.kubernetes.io/warn-version'
        ])) &&
        object.spec == oldObject.spec && object.status == oldObject.status
      message: Разрешено изменять только стандартные метки Pod Security Admission.
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: propdevelopment-psa-labels-only
spec:
  policyName: propdevelopment-psa-labels-only
  validationActions: [Deny]
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
