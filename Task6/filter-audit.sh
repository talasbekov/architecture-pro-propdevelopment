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

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT
validated="$workdir/validated.jsonl"
result="$workdir/result.json"

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

jq -s '
  map(select(
    (.verb? == "get" and .objectRef?.resource? == "secrets")
    or
    (.verb? == "create" and .objectRef?.resource? == "pods" and
      any((.requestObject?.spec?.containers? // [])[]?; .securityContext?.privileged? == true))
    or
    (.verb? == "create" and .objectRef?.resource? == "pods" and .objectRef?.subresource? == "exec")
    or
    (.verb? == "create" and
      (.objectRef?.resource? == "rolebindings" or .objectRef?.resource? == "clusterrolebindings") and
      .requestObject?.roleRef?.kind? == "ClusterRole" and
      .requestObject?.roleRef?.name? == "cluster-admin")
    or
    ((tostring | ascii_downcase) | contains("audit-policy"))
  ))
' "$validated" >"$result"

mkdir -p "$(dirname "$output")"
mv "$result" "$output"
