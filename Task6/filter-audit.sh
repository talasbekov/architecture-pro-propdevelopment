#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Использование: $0 <audit.jsonl> <результат.json>" >&2
  exit 64
fi

input=$1
output=$2

if [[ ! -r "$input" ]]; then
  echo "Не удаётся прочитать входной файл: $input" >&2
  exit 66
fi

output_dir=$(dirname "$output")
output_name=$(basename "$output")
mkdir -p "$output_dir"

workdir=$(mktemp -d)
output_temp=""
cleanup() {
  rm -rf "$workdir"
  if [[ -n "$output_temp" ]]; then
    rm -f "$output_temp"
  fi
}
trap cleanup EXIT
validated="$workdir/validated.jsonl"

: >"$validated"
line_number=0
while IFS= read -r line || [[ -n "$line" ]]; do
  ((line_number += 1))
  if ! jq empty >/dev/null 2>"$workdir/jq-error" <<<"$line"; then
    echo "Некорректный JSON в строке $line_number: $(<"$workdir/jq-error")" >&2
    exit 65
  fi
  printf '%s\n' "$line" >>"$validated"
done <"$input"

output_temp=$(mktemp "$output_dir/.${output_name}.tmp.XXXXXX")
jq -s '
  def contains_audit_policy:
    any(.. | strings; ascii_downcase | contains("audit-policy"));
  def audit_policy_mention:
    [
      .objectRef?.name?,
      .objectRef?.resource?,
      .objectRef?.subresource?,
      .requestURI?,
      .requestObject?.metadata?.name?,
      .requestObject?.path?,
      .requestObject?.command?,
      .requestObject?.args?
    ] | any(.[]; contains_audit_policy);
  map(select(
    (.verb? == "get" and .objectRef?.resource? == "secrets")
    or
    (.verb? == "create" and .objectRef?.resource? == "pods" and
      any((
        ((.requestObject?.spec?.containers? // [])
          + (.requestObject?.spec?.initContainers? // [])
          + (.requestObject?.spec?.ephemeralContainers? // []))[]?
      ); .securityContext?.privileged? == true))
    or
    (.verb? == "create" and .objectRef?.resource? == "pods" and .objectRef?.subresource? == "exec")
    or
    (.verb? == "create" and
      (.objectRef?.resource? == "rolebindings" or .objectRef?.resource? == "clusterrolebindings") and
      .requestObject?.roleRef?.kind? == "ClusterRole" and
      .requestObject?.roleRef?.name? == "cluster-admin")
    or
    audit_policy_mention
  ))
  | map(
      if audit_policy_mention then
        ._propdevelopment = ((._propdevelopment // {}) + {
          indicator: "audit-policy",
          classification: "mention"
        })
      else
        .
      end
    )
' "$validated" >"$output_temp"
jq empty "$output_temp"
mv "$output_temp" "$output"
output_temp=""
