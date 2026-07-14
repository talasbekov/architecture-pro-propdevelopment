#!/usr/bin/env bash
set -euo pipefail

# Привязки используют только роли, созданные скриптом 02-create-roles.sh.
render() {
cat <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdevelopment-cluster-viewers
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-viewer
subjects:
  - kind: Group
    name: propdevelopment-viewers
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdevelopment-platform-operators
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-operator
subjects:
  - kind: Group
    name: propdevelopment-platform-operators
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: propdevelopment-developers
  namespace: propdevelopment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: namespace-developer
subjects:
  - kind: Group
    name: propdevelopment-developers
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: propdevelopment-security-secret-readers
  namespace: propdevelopment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: security-secret-reader
subjects:
  - kind: Group
    name: propdevelopment-security-auditors
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: propdevelopment-limited-security-admins
  namespace: propdevelopment
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: limited-security-admin
subjects:
  - kind: Group
    name: propdevelopment-security-admins
    apiGroup: rbac.authorization.k8s.io
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
