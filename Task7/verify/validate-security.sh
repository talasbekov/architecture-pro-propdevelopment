#!/usr/bin/env bash
set -Eeuo pipefail

VERIFY_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="$(dirname -- "$VERIFY_DIR")"
GATEKEEPER_VERSION="${GATEKEEPER_VERSION:-v3.22.2}"
INSTALL_GATEKEEPER="${INSTALL_GATEKEEPER:-false}"
GATEKEEPER_MANIFEST="https://raw.githubusercontent.com/open-policy-agent/gatekeeper/${GATEKEEPER_VERSION}/deploy/gatekeeper.yaml"
template_names=(k8sdenyprivileged k8sdenyhostpath k8srequirerestrictedcontainer)
constraint_files=(privileged.yaml hostpath.yaml runasnonroot.yaml)
test_namespace_created=false
policy_resources_created=false

cleanup() {
  local rc=$?
  [[ "$test_namespace_created" == false ]] || kubectl delete namespace gatekeeper-test --ignore-not-found --wait=false >/dev/null 2>&1 || true
  if [[ "$policy_resources_created" == true ]]; then
    for file in "${constraint_files[@]}"; do
      kubectl delete -f "$TASK_DIR/gatekeeper/constraints/$file" --ignore-not-found >/dev/null 2>&1 || true
    done
    for name in "${template_names[@]}"; do
      kubectl delete constrainttemplate "$name" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    done
  fi
  exit "$rc"
}
trap cleanup EXIT

command -v kubectl >/dev/null || { echo "Ошибка: kubectl не найден" >&2; exit 1; }
command -v docker >/dev/null || { echo "Ошибка: docker не найден (нужен для yq 4.44.3)" >&2; exit 1; }
docker run --rm -i mikefarah/yq:4.44.3 e -e \
  'select(.apiVersion == "audit.k8s.io/v1" and .kind == "Policy" and (.rules | type == "!!seq"))' - \
  < "$TASK_DIR/audit-policy.yaml" >/dev/null
kubectl cluster-info >/dev/null

if [[ "$INSTALL_GATEKEEPER" == true ]]; then
  echo "Устанавливаю Gatekeeper $GATEKEEPER_VERSION"
  kubectl apply -f "$GATEKEEPER_MANIFEST"
fi
kubectl get namespace gatekeeper-system >/dev/null 2>&1 || { echo "Gatekeeper не установлен. Запустите с INSTALL_GATEKEEPER=true." >&2; exit 1; }
kubectl rollout status deployment/gatekeeper-controller-manager -n gatekeeper-system --timeout=180s

for name in "${template_names[@]}"; do
  ! kubectl get constrainttemplate "$name" >/dev/null 2>&1 || { echo "Ошибка: ConstraintTemplate $name уже существует." >&2; exit 1; }
done
for resource in k8sdenyprivileged/deny-privileged-pods k8sdenyhostpath/deny-hostpath-pods k8srequirerestrictedcontainer/require-restricted-container-settings; do
  ! kubectl get "$resource" >/dev/null 2>&1 || { echo "Ошибка: constraint $resource уже существует." >&2; exit 1; }
done
! kubectl get namespace gatekeeper-test >/dev/null 2>&1 || { echo "Ошибка: Namespace gatekeeper-test уже существует." >&2; exit 1; }

policy_resources_created=true
kubectl apply -f "$TASK_DIR/gatekeeper/constraint-templates"
for crd in k8sdenyprivileged.constraints.gatekeeper.sh k8sdenyhostpath.constraints.gatekeeper.sh k8srequirerestrictedcontainer.constraints.gatekeeper.sh; do
  kubectl wait --for=condition=Established "crd/$crd" --timeout=120s
done
kubectl apply -f "$TASK_DIR/gatekeeper/constraints"
kubectl create namespace gatekeeper-test
test_namespace_created=true

manifests=(01-privileged-pod.yaml 02-hostpath-pod.yaml 03-root-user-pod.yaml)
constraint_names=(deny-privileged-pods deny-hostpath-pods require-restricted-container-settings)
policy_markers=(K8sDenyPrivileged K8sDenyHostPath K8sRequireRestrictedContainer)
for i in "${!manifests[@]}"; do
  manifest="$TASK_DIR/insecure-manifests/${manifests[$i]}"
  if rejection="$(sed 's/namespace: audit-zone/namespace: gatekeeper-test/' "$manifest" | kubectl apply --dry-run=server --request-timeout=30s -f - 2>&1)"; then
    echo "Ошибка: Gatekeeper принял нарушение $manifest" >&2
    exit 1
  fi
  if [[ "$rejection" != *"[${constraint_names[$i]}]"* || "$rejection" != *"${policy_markers[$i]}"* ]]; then
    echo "Ошибка проверки $manifest: нет решения ожидаемой политики ${policy_markers[$i]}/${constraint_names[$i]}:" >&2
    echo "$rejection" >&2
    exit 1
  fi
  echo "Gatekeeper ожидаемо отклонил ${manifests[$i]} политикой ${constraint_names[$i]}"
done
for manifest in "$TASK_DIR"/secure-manifests/*.yaml; do
  sed 's/namespace: audit-zone/namespace: gatekeeper-test/' "$manifest" | kubectl apply --dry-run=server --request-timeout=30s -f - >/dev/null
  echo "Gatekeeper принял $(basename "$manifest")"
done
echo "Gatekeeper отклонил 3 изолированных нарушения и принял 3 безопасных манифеста."
