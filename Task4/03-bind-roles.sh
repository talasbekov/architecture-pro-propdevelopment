#!/usr/bin/env bash
set -euo pipefail

# Привязки используют только роли, созданные скриптом 02-create-roles.sh.
# Домены и их namespace должны совпадать с DOMAIN_NAMESPACES из 02-create-roles.sh.
readonly DOMAIN_NAMESPACES=(sales tenant-services finance data-platform)

# domain_group_suffix переводит имя namespace в суффикс доменной группы,
# например tenant-services -> tenant.
domain_group_suffix() {
  case "$1" in
    sales) echo "sales" ;;
    tenant-services) echo "tenant" ;;
    finance) echo "finance" ;;
    data-platform) echo "data" ;;
    *) echo "$1" ;;
  esac
}

render_static_head() {
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
    name: viewers
    apiGroup: rbac.authorization.k8s.io
---
YAML
}

render_domain_bindings() {
  local ns suffix
  for ns in "${DOMAIN_NAMESPACES[@]}"; do
    suffix="$(domain_group_suffix "${ns}")"
    cat <<YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ns}-developers
  namespace: ${ns}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: namespace-developer
subjects:
  - kind: Group
    name: developers-${suffix}
    apiGroup: rbac.authorization.k8s.io
YAML
    # developer1 демонстрирует доступ строго к своему домену (sales).
    if [[ "${ns}" == "sales" ]]; then
      cat <<'YAML'
  - kind: User
    name: developer1
    apiGroup: rbac.authorization.k8s.io
YAML
    fi
    cat <<YAML
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ns}-platform-operators
  namespace: ${ns}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-operator
subjects:
  - kind: Group
    name: platform-operators-${suffix}
    apiGroup: rbac.authorization.k8s.io
YAML
    # operator1 демонстрирует доступ строго к своему домену (tenant-services / ЖКУ).
    if [[ "${ns}" == "tenant-services" ]]; then
      cat <<'YAML'
  - kind: User
    name: operator1
    apiGroup: rbac.authorization.k8s.io
YAML
    fi
    cat <<YAML
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ns}-security-secret-readers
  namespace: ${ns}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: security-secret-reader
subjects:
  - kind: Group
    name: security
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ns}-limited-security-admins
  namespace: ${ns}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: limited-security-admin
subjects:
  - kind: Group
    name: security
    apiGroup: rbac.authorization.k8s.io
---
YAML
  done
}

render_static_tail() {
cat <<'YAML'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdevelopment-platform-operator-cluster-readers
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: platform-operator-cluster-reader
subjects:
  - kind: Group
    name: platform-operators-sales
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: platform-operators-tenant
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: platform-operators-finance
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: platform-operators-data
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: propdevelopment-limited-security-admins-psa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: limited-security-admin-psa
subjects:
  - kind: Group
    name: security
    apiGroup: rbac.authorization.k8s.io
YAML
}

render() {
  render_static_head
  render_domain_bindings
  render_static_tail
}

if [[ "${1:-}" == "--render" ]]; then
  render
elif [[ $# -eq 0 ]]; then
  render | kubectl apply -f -
else
  echo "Использование: $0 [--render]" >&2
  exit 2
fi
