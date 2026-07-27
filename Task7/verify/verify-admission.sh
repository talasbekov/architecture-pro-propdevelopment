#!/usr/bin/env bash
set -Eeuo pipefail

VERIFY_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="$(dirname -- "$VERIFY_DIR")"
namespace_created=false
created_pods=()
secure_pods=(secure-privileged-alternative secure-hostpath-alternative secure-root-alternative)

cleanup() {
  local rc=$?
  if [[ "$namespace_created" == true ]]; then
    kubectl delete namespace audit-zone --ignore-not-found --wait=false >/dev/null 2>&1 || true
  elif ((${#created_pods[@]})); then
    kubectl delete pod -n audit-zone "${created_pods[@]}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT

command -v kubectl >/dev/null || { echo "Ошибка: kubectl не найден" >&2; exit 1; }
kubectl cluster-info >/dev/null

if kubectl get namespace audit-zone >/dev/null 2>&1; then
  for pod in "${secure_pods[@]}"; do
    if kubectl get pod -n audit-zone "$pod" >/dev/null 2>&1; then
      echo "Ошибка: Pod audit-zone/$pod уже существует; чужой ресурс не будет изменён." >&2
      exit 1
    fi
  done
  kubectl apply -f "$TASK_DIR/01-create-namespace.yaml"
else
  kubectl apply -f "$TASK_DIR/01-create-namespace.yaml"
  namespace_created=true
fi

for manifest in "$TASK_DIR"/insecure-manifests/*.yaml; do
  if rejection="$(kubectl apply --server-side --dry-run=server -f "$manifest" 2>&1)"; then
    echo "Ошибка: PSA принял небезопасный манифест $manifest" >&2
    exit 1
  fi
  if [[ "$rejection" != *"violates PodSecurity"* ]]; then
    echo "Ошибка проверки $manifest: отказ вызван не PSA:" >&2
    echo "$rejection" >&2
    exit 1
  fi
  echo "PSA ожидаемо отклонил $(basename "$manifest")"
done

for manifest in "$TASK_DIR"/secure-manifests/*.yaml; do
  pod_name="$(kubectl create --dry-run=client -f "$manifest" -o jsonpath='{.metadata.name}')"
  kubectl apply -f "$manifest"
  created_pods+=("$pod_name")
done
for pod in "${secure_pods[@]}"; do
  kubectl wait --namespace audit-zone --for=condition=Ready "pod/$pod" --timeout=180s
done
echo "PSA отклонил 3 нарушения; 3 безопасных Pod запущены и готовы."
