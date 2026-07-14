#!/usr/bin/env bash
set -euo pipefail

# Создаёт клиентские сертификаты и отдельные kubeconfig для учебных пользователей.
command -v kubectl >/dev/null || { echo "Не найден kubectl" >&2; exit 1; }
command -v openssl >/dev/null || { echo "Не найден openssl" >&2; exit 1; }

readonly TASK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CREDENTIALS_DIR="${TASK_DIR}/.credentials"
mkdir -p "${CREDENTIALS_DIR}"
chmod 700 "${CREDENTIALS_DIR}"

create_user() {
  local user="$1" group="$2"
  local key="${CREDENTIALS_DIR}/${user}.key"
  local cert="${CREDENTIALS_DIR}/${user}.crt"
  local request_file="${CREDENTIALS_DIR}/${user}.csr"
  local kubeconfig="${CREDENTIALS_DIR}/${user}.kubeconfig"
  local csr_name="propdevelopment-${user}"

  if [[ -f "${key}" && -f "${cert}" ]]; then
    echo "${user}: готовые ключ и сертификат уже существуют"
  elif [[ -e "${key}" || -e "${cert}" ]]; then
    echo "${user}: найден неполный комплект key/cert; удалите или восстановите его вручную" >&2
    return 1
  else
    openssl genrsa -out "${key}" 2048
    chmod 600 "${key}"
    openssl req -new -key "${key}" -out "${request_file}" -subj "/CN=${user}/O=${group}"

    local encoded_request existing_request existing_signer
    encoded_request="$(base64 < "${request_file}" | tr -d '\n')"
    if kubectl get csr "${csr_name}" >/dev/null 2>&1; then
      existing_request="$(kubectl get csr "${csr_name}" -o jsonpath='{.spec.request}')"
      existing_signer="$(kubectl get csr "${csr_name}" -o jsonpath='{.spec.signerName}')"
      if [[ "${existing_request}" != "${encoded_request}" || "${existing_signer}" != "kubernetes.io/kube-apiserver-client" ]]; then
        echo "${user}: существующий CSR ${csr_name} создан для другого запроса" >&2
        return 1
      fi
    else
      kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${csr_name}
spec:
  request: ${encoded_request}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000
  usages:
    - client auth
EOF
    fi

    kubectl certificate approve "${csr_name}" >/dev/null 2>&1 || true
    local certificate=""
    for _ in $(seq 1 60); do
      certificate="$(kubectl get csr "${csr_name}" -o jsonpath='{.status.certificate}')"
      [[ -n "${certificate}" ]] && break
      sleep 2
    done
    [[ -n "${certificate}" ]] || { echo "${user}: сертификат не выдан за 120 секунд" >&2; return 1; }
    printf '%s' "${certificate}" | base64 --decode > "${cert}"
    chmod 600 "${cert}"
  fi

  local context cluster server ca_data
  context="$(kubectl config current-context)"
  cluster="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}')"
  server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
  ca_data="$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
  kubectl config --kubeconfig="${kubeconfig}" set-cluster "${cluster}" --server="${server}" ${ca_data:+--certificate-authority-data="${ca_data}"} >/dev/null
  kubectl config --kubeconfig="${kubeconfig}" set-credentials "${user}" --client-certificate="${cert}" --client-key="${key}" --embed-certs=true >/dev/null
  kubectl config --kubeconfig="${kubeconfig}" set-context "${context}" --cluster="${cluster}" --user="${user}" --namespace=propdevelopment >/dev/null
  kubectl config --kubeconfig="${kubeconfig}" use-context "${context}" >/dev/null
  chmod 600 "${kubeconfig}"
  echo "${user}: kubeconfig сохранён в ${kubeconfig}"
}

create_user developer1 propdevelopment-developers
create_user operator1 propdevelopment-platform-operators
