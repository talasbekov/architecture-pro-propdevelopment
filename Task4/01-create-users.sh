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
  local user="$1" group="$2" namespace="$3"
  local key="${CREDENTIALS_DIR}/${user}.key"
  local cert="${CREDENTIALS_DIR}/${user}.crt"
  local request_file="${CREDENTIALS_DIR}/${user}.csr"
  local kubeconfig="${CREDENTIALS_DIR}/${user}.kubeconfig"
  local csr_name="propdevelopment-${user}"

  if [[ -f "${key}" && -f "${cert}" ]]; then
    local key_public cert_public subject
    key_public="$(openssl pkey -in "${key}" -pubout 2>/dev/null)" || { echo "${user}: ключ повреждён; восстановите комплект из резервной копии или удалите key/cert" >&2; return 1; }
    cert_public="$(openssl x509 -in "${cert}" -pubkey -noout 2>/dev/null)" || { echo "${user}: сертификат повреждён; восстановите комплект из резервной копии или удалите key/cert" >&2; return 1; }
    [[ "${key_public}" == "${cert_public}" ]] || { echo "${user}: ключ и сертификат не образуют пару; восстановите или удалите оба файла" >&2; return 1; }
    subject="$(openssl x509 -in "${cert}" -noout -subject -nameopt RFC2253)"
    [[ "${subject}" == "subject=O=${group},CN=${user}" ]] || { echo "${user}: subject сертификата не совпадает с точным CN/O; восстановите или удалите комплект" >&2; return 1; }
    openssl x509 -in "${cert}" -checkend 0 -noout >/dev/null || { echo "${user}: сертификат истёк; удалите cert и key для безопасного перевыпуска" >&2; return 1; }
    openssl x509 -in "${cert}" -purpose -noout | grep -q '^SSL client : Yes$' || { echo "${user}: сертификат не разрешён для client authentication" >&2; return 1; }
    echo "${user}: существующий комплект key/cert проверен"
  elif [[ -e "${key}" || -e "${cert}" ]]; then
    echo "${user}: найден неполный комплект key/cert; восстановите отсутствующий файл из резервной копии или удалите оба для перевыпуска" >&2
    return 1
  else
    # Без локального сертификата старый CSR нельзя безопасно продолжить: удаляем только CSR.
    if kubectl get csr "${csr_name}" >/dev/null 2>&1; then
      kubectl delete csr "${csr_name}"
    fi

    local temp_dir temp_key temp_cert temp_request
    temp_dir="$(mktemp -d "${CREDENTIALS_DIR}/.${user}.XXXXXX")"
    temp_key="${temp_dir}/${user}.key"
    temp_cert="${temp_dir}/${user}.crt"
    temp_request="${temp_dir}/${user}.csr"
    trap 'rm -rf "${temp_dir}"' RETURN
    openssl genrsa -out "${temp_key}" 2048
    chmod 600 "${temp_key}"
    openssl req -new -key "${temp_key}" -out "${temp_request}" -subj "/CN=${user}/O=${group}"

    local encoded_request
    encoded_request="$(base64 < "${temp_request}" | tr -d '\n')"
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

    kubectl certificate approve "${csr_name}" >/dev/null 2>&1 || true
    local certificate=""
    for _ in $(seq 1 60); do
      certificate="$(kubectl get csr "${csr_name}" -o jsonpath='{.status.certificate}')"
      [[ -n "${certificate}" ]] && break
      sleep 2
    done
    [[ -n "${certificate}" ]] || { echo "${user}: сертификат не выдан за 120 секунд" >&2; return 1; }
    printf '%s' "${certificate}" | base64 --decode > "${temp_cert}"
    chmod 600 "${temp_cert}"
    mv "${temp_key}" "${key}"
    mv "${temp_cert}" "${cert}"
    mv "${temp_request}" "${request_file}"
    trap - RETURN
    rm -rf "${temp_dir}"
  fi

  local context cluster server ca_data insecure ca_file
  context="$(kubectl config current-context)"
  cluster="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}')"
  server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
  # --flatten встраивает CA даже тогда, когда исходный kubeconfig ссылался на файл.
  ca_data="$(kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
  insecure="$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.insecure-skip-tls-verify}')"
  local -a cluster_args=(--server="${server}")
  if [[ -n "${ca_data}" ]]; then
    ca_file="$(mktemp "${CREDENTIALS_DIR}/.cluster-ca.XXXXXX")"
    trap 'rm -f "${ca_file}"' RETURN
    printf '%s' "${ca_data}" | base64 --decode > "${ca_file}"
    chmod 600 "${ca_file}"
    cluster_args+=(--certificate-authority="${ca_file}" --embed-certs=true)
  elif [[ "${ALLOW_INSECURE_SKIP_TLS_VERIFY:-false}" == "true" && "${insecure}" == "true" ]]; then
    cluster_args+=(--insecure-skip-tls-verify=true)
  else
    echo "Не удалось встроить CA кластера; небезопасный режим разрешается только через ALLOW_INSECURE_SKIP_TLS_VERIFY=true" >&2
    return 1
  fi
  kubectl config --kubeconfig="${kubeconfig}" set-cluster "${cluster}" "${cluster_args[@]}" >/dev/null
  if [[ -n "${ca_file:-}" ]]; then
    trap - RETURN
    rm -f "${ca_file}"
  fi
  kubectl config --kubeconfig="${kubeconfig}" set-credentials "${user}" --client-certificate="${cert}" --client-key="${key}" --embed-certs=true >/dev/null
  kubectl config --kubeconfig="${kubeconfig}" set-context "${context}" --cluster="${cluster}" --user="${user}" --namespace="${namespace}" >/dev/null
  kubectl config --kubeconfig="${kubeconfig}" use-context "${context}" >/dev/null
  chmod 600 "${kubeconfig}"
  echo "${user}: kubeconfig сохранён в ${kubeconfig}"
}

create_user developer1 developers-sales sales
create_user operator1 platform-operators-tenant tenant-services
