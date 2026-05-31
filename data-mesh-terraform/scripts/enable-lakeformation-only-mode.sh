#!/usr/bin/env bash
# Remove IAM_ALLOWED_PRINCIPALS dos defaults do Lake Formation (modo LF-only).
# Necessário para column-level security (ex.: bloquear faixa_salarial) no Athena.
#
# Deve ser executado por principal SEM deny em lakeformation:PutDataLakeSettings
# (ex.: usuário root da conta). usuario-dados com AWSLakeFormationDataAdmin recebe deny.
#
# Uso:
#   bash scripts/enable-lakeformation-only-mode.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="${SCRIPT_DIR}/lf-put-input.json"

if [[ ! -f "$INPUT" ]]; then
  echo "Arquivo não encontrado: ${INPUT}" >&2
  exit 1
fi

echo "Aplicando Lake Formation LF-only (sem IAM_ALLOWED_PRINCIPALS)..."
aws lakeformation put-data-lake-settings --cli-input-json "file://${INPUT}"
echo "OK. Rode novamente: bash scripts/validate-e2e.sh"
