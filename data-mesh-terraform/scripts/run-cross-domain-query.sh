#!/usr/bin/env bash
# Executa a query cross-domínio no Athena (wg-analytics) e exibe as 10 primeiras linhas.
#
# Uso:
#   chmod +x scripts/run-cross-domain-query.sh
#   ./scripts/run-cross-domain-query.sh
#
# Requisitos: aws CLI (sem jq)
#
# Variáveis opcionais:
#   AWS_REGION, PROJECT_NAME, ENVIRONMENT, WORKGROUP, ROLE_ANALYTICS_ARN
#   QUERY_FILE (default: scripts/queries/cross-domain-vendas-rh.sql)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-data-mesh}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
WORKGROUP="${WORKGROUP:-wg-analytics}"
QUERY_FILE="${QUERY_FILE:-${SCRIPT_DIR}/queries/cross-domain-vendas-rh.sql}"
CATALOG="${CATALOG:-AwsDataCatalog}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-2}"
MAX_POLL_ATTEMPTS="${MAX_POLL_ATTEMPTS:-90}"

ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)}"
ROLE_ANALYTICS_ARN="${ROLE_ANALYTICS_ARN:-arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT_NAME}-role-analytics-${ENVIRONMENT}}"

export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_REGION="$AWS_REGION"

die() {
  echo "Erro: $1" >&2
  exit 1
}

require_cmd() {
  command -v aws >/dev/null 2>&1 || die "comando não encontrado: aws"
}

is_analytics_role_session() {
  local caller_arn
  caller_arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "")
  [[ "$caller_arn" == *":assumed-role/${PROJECT_NAME}-role-analytics-${ENVIRONMENT}/"* ]] \
    || [[ "$caller_arn" == "$ROLE_ANALYTICS_ARN" ]]
}

assume_analytics_role() {
  if is_analytics_role_session; then
    echo "  · Sessão atual já é a role-analytics — pulando AssumeRole."
    ASSUMED_IN_THIS_RUN=false
    return 0
  fi

  local creds_line
  creds_line=$(aws sts assume-role \
    --role-arn "$ROLE_ANALYTICS_ARN" \
    --role-session-name "cross-domain-query" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text 2>&1) || die "sts assume-role falhou: ${creds_line}

Dica: se você rodou 'aws sts assume-role' antes neste terminal, volte ao usuário IAM:
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
Ou abra um terminal novo e rode o script de novo."

  read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<< "$creds_line"
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  ASSUMED_IN_THIS_RUN=true
}

restore_credentials() {
  if [[ -n "${SAVED_AWS_ACCESS_KEY_ID:-}" ]]; then
    export AWS_ACCESS_KEY_ID="$SAVED_AWS_ACCESS_KEY_ID"
    export AWS_SECRET_ACCESS_KEY="$SAVED_AWS_SECRET_ACCESS_KEY"
    if [[ -n "${SAVED_AWS_SESSION_TOKEN:-}" ]]; then
      export AWS_SESSION_TOKEN="$SAVED_AWS_SESSION_TOKEN"
    else
      unset AWS_SESSION_TOKEN
    fi
  fi
}

read_query() {
  [[ -f "$QUERY_FILE" ]] || die "arquivo SQL não encontrado: ${QUERY_FILE}"
  grep -v '^[[:space:]]*--' "$QUERY_FILE" | tr -d '\r' | paste -sd ' ' -
}

poll_query() {
  local execution_id="$1"
  local state reason output_location
  local attempt=0

  while [[ $attempt -lt $MAX_POLL_ATTEMPTS ]]; do
    state=$(aws athena get-query-execution \
      --query-execution-id "$execution_id" \
      --query 'QueryExecution.Status.State' \
      --output text)

    reason=$(aws athena get-query-execution \
      --query-execution-id "$execution_id" \
      --query 'QueryExecution.Status.StateChangeReason' \
      --output text)

    output_location=$(aws athena get-query-execution \
      --query-execution-id "$execution_id" \
      --query 'QueryExecution.ResultConfiguration.OutputLocation' \
      --output text)

    [[ "$reason" == "None" ]] && reason=""
    [[ "$output_location" == "None" ]] && output_location=""

    case "$state" in
      SUCCEEDED)
        echo "$output_location"
        return 0
        ;;
      FAILED|CANCELLED)
        echo "FAILED|${reason}|" >&2
        return 1
        ;;
    esac

    sleep "$POLL_INTERVAL_SECONDS"
    attempt=$((attempt + 1))
  done

  die "timeout aguardando query ${execution_id}"
}

download_and_print() {
  local s3_uri="$1"
  local local_csv
  local_csv="$(mktemp /tmp/athena-result-XXXXXX.csv)"

  aws s3 cp "$s3_uri" "$local_csv" >/dev/null || die "falha ao baixar ${s3_uri}"

  echo
  echo "Resultado (10 primeiras linhas):"
  echo "----------------------------------------"
  head -n 11 "$local_csv"
  echo "----------------------------------------"
  echo "Arquivo completo: ${local_csv}"
}

main() {
  require_cmd

  local query_string
  query_string="$(read_query)"

  echo "Cross-domínio Athena"
  echo "WorkGroup : ${WORKGROUP}"
  echo "Catalog   : ${CATALOG}"
  echo "Role      : ${ROLE_ANALYTICS_ARN}"
  echo "Query file: ${QUERY_FILE}"
  echo

  SAVED_AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
  SAVED_AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
  SAVED_AWS_SESSION_TOKEN="${AWS_SESSION_TOKEN:-}"
  ASSUMED_IN_THIS_RUN=false

  assume_analytics_role

  local execution_id
  execution_id=$(aws athena start-query-execution \
    --work-group "$WORKGROUP" \
    --query-execution-context "Catalog=${CATALOG}" \
    --query-string "$query_string" \
    --query 'QueryExecutionId' \
    --output text) || die "start-query-execution falhou"

  echo "QueryExecutionId: ${execution_id}"
  echo "Aguardando conclusão..."

  local output_location
  if ! output_location="$(poll_query "$execution_id")"; then
    die "query não concluiu com sucesso (veja mensagem acima)"
  fi

  echo "OutputLocation: ${output_location}"
  download_and_print "$output_location"

  if [[ "${ASSUMED_IN_THIS_RUN:-false}" == true ]]; then
    restore_credentials
  fi
}

main "$@"
