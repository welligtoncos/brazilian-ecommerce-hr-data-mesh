#!/usr/bin/env bash
# Validação Sprint 3 — Lake Formation (isolamento + column-level security) e Athena
#
# Uso:
#   chmod +x scripts/validate-sprint3.sh
#   ./scripts/validate-sprint3.sh
#
# Variáveis opcionais (defaults alinhados ao terraform.tfvars):
#   AWS_REGION, PROJECT_NAME, ENVIRONMENT, ACCOUNT_ID
#   ROLE_GLUE_VENDAS_ARN, ROLE_ANALYTICS_ARN, ATHENA_RESULTS_BUCKET, WORKGROUP

set -uo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-data-mesh}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
WORKGROUP="${WORKGROUP:-wg-analytics}"
ATHENA_RESULTS_BUCKET="${ATHENA_RESULTS_BUCKET:-${PROJECT_NAME}-athena-results-${ENVIRONMENT}}"
VENDAS_DB="${VENDAS_DB:-vendas_db}"
RH_DB="${RH_DB:-rh_db}"
VENDAS_TABLE="${VENDAS_TABLE:-vendas_por_categoria}"
RH_TABLE="${RH_TABLE:-funcionarios}"
# Coluna de valor na tabela vendas (Sprint 2 usa total_vendas; ajuste se renomeou para total_receita)
VENDAS_VALUE_COLUMN="${VENDAS_VALUE_COLUMN:-total_vendas}"

ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)}"
ROLE_GLUE_VENDAS_ARN="${ROLE_GLUE_VENDAS_ARN:-arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT_NAME}-role-glue-vendas-${ENVIRONMENT}}"
ROLE_ANALYTICS_ARN="${ROLE_ANALYTICS_ARN:-arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT_NAME}-role-analytics-${ENVIRONMENT}}"

export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_REGION="$AWS_REGION"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "[PASS] $1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "[FAIL] $1"
}

require_cmd() {
  command -v aws >/dev/null 2>&1 || {
    echo "Erro: comando obrigatório não encontrado: aws" >&2
    exit 2
  }
}

lf_principal_has_permission() {
  local resource_json="$1"
  local principal_arn="$2"
  local permission="$3"
  local perms

  perms=$(aws lakeformation list-permissions \
    --resource "$resource_json" \
    --query "PrincipalResourcePermissions[?Principal.DataLakePrincipalIdentifier=='${principal_arn}'].Permissions[]" \
    --output text 2>/dev/null) || return 1

  [[ -z "$perms" || "$perms" == "None" ]] && return 1
  echo "$perms" | tr '\t' '\n' | grep -Fxq "$permission"
}

check_1_lf_database_permissions() {
  echo
  echo "=== Check 1 — Permissões LF por database (vendas_db) ==="

  local db_resource="{\"Database\":{\"Name\":\"${VENDAS_DB}\"}}"
  local table_resource="{\"Table\":{\"DatabaseName\":\"${VENDAS_DB}\",\"Name\":\"${VENDAS_TABLE}\"}}"
  local ok=true

  if lf_principal_has_permission "$db_resource" "$ROLE_GLUE_VENDAS_ARN" "ALL"; then
    echo "  · role-glue-vendas possui ALL em ${VENDAS_DB}"
  else
    ok=false
    echo "  · role-glue-vendas NÃO possui ALL em ${VENDAS_DB}"
  fi

  # SELECT da role-analytics foi concedido na TABELA (Sprint 3), não no database.
  if lf_principal_has_permission "$table_resource" "$ROLE_ANALYTICS_ARN" "SELECT"; then
    echo "  · role-analytics possui SELECT em ${VENDAS_DB}.${VENDAS_TABLE}"
  else
    ok=false
    echo "  · role-analytics NÃO possui SELECT em ${VENDAS_DB}.${VENDAS_TABLE}"
  fi

  if [[ "$ok" == true ]]; then
    pass "Check 1 — produtor Vendas com ALL no database; analytics com SELECT na tabela ${VENDAS_TABLE}"
  else
    fail "Check 1 — permissões esperadas ausentes em vendas_db / ${VENDAS_TABLE}"
  fi
}

check_2_column_level_security() {
  echo
  echo "=== Check 2 — Column-level security (rh_db.funcionarios) ==="

  local col_resource="{\"TableWithColumns\":{\"DatabaseName\":\"${RH_DB}\",\"Name\":\"${RH_TABLE}\",\"ColumnWildcard\":{}}}"
  local granted_columns wildcard

  if ! aws lakeformation list-permissions --resource "$col_resource" >/dev/null 2>&1; then
    fail "Check 2 — não foi possível listar permissões TableWithColumns em ${RH_DB}.${RH_TABLE}"
    return
  fi

  granted_columns=$(aws lakeformation list-permissions \
    --resource "$col_resource" \
    --query "PrincipalResourcePermissions[?Principal.DataLakePrincipalIdentifier=='${ROLE_ANALYTICS_ARN}'].ColumnNames[]" \
    --output text 2>/dev/null | tr '\t' '\n' | sort -u)

  wildcard=$(aws lakeformation list-permissions \
    --resource "$col_resource" \
    --query "PrincipalResourcePermissions[?Principal.DataLakePrincipalIdentifier=='${ROLE_ANALYTICS_ARN}'].ColumnWildcard" \
    --output text 2>/dev/null)

  if [[ -z "$granted_columns" && ( -z "$wildcard" || "$wildcard" == "None" ) ]]; then
    fail "Check 2 — nenhuma permissão encontrada para role-analytics em ${RH_DB}.${RH_TABLE}"
    return
  fi

  if echo "$granted_columns" | grep -qx "faixa_salarial"; then
    fail "Check 2 — faixa_salarial aparece nas colunas concedidas à role-analytics (não deveria)"
    return
  fi

  if [[ -n "$wildcard" && "$wildcard" != "None" ]]; then
    fail "Check 2 — role-analytics possui ColumnWildcard (acesso a todas as colunas)"
    return
  fi

  if [[ -z "$granted_columns" ]]; then
    fail "Check 2 — nenhuma coluna explícita listada para role-analytics"
    return
  fi

  echo "  · Colunas concedidas à role-analytics:"
  echo "$granted_columns" | sed 's/^/    - /'
  pass "Check 2 — faixa_salarial NÃO está nas colunas concedidas à role-analytics"
}

check_3_athena_workgroup() {
  echo
  echo "=== Check 3 — Workgroup Athena (wg-analytics) ==="

  local state location

  if ! state=$(aws athena get-work-group \
    --work-group "$WORKGROUP" \
    --query 'WorkGroup.State' \
    --output text 2>&1); then
    fail "Check 3 — get-work-group falhou: ${state}"
    return
  fi

  location=$(aws athena get-work-group \
    --work-group "$WORKGROUP" \
    --query 'WorkGroup.Configuration.ResultConfiguration.OutputLocation' \
    --output text 2>/dev/null)

  [[ "$location" == "None" ]] && location=""

  local ok=true
  [[ "$state" == "ENABLED" ]] || ok=false
  [[ -n "$location" ]] || ok=false

  echo "  · State: ${state:-<vazio>}"
  echo "  · OutputLocation: ${location:-<vazio>}"

  if [[ "$ok" == true ]]; then
    pass "Check 3 — workgroup ${WORKGROUP} ENABLED com output_location configurado"
  else
    fail "Check 3 — workgroup ${WORKGROUP} inativo ou sem output_location"
  fi
}

check_4_results_bucket_lifecycle() {
  echo
  echo "=== Check 4 — Lifecycle do bucket de resultados Athena ==="

  local expiration_days

  if ! expiration_days=$(aws s3api get-bucket-lifecycle-configuration \
    --bucket "$ATHENA_RESULTS_BUCKET" \
    --query 'Rules[0].Expiration.Days' \
    --output text 2>&1); then
    fail "Check 4 — lifecycle não encontrado em ${ATHENA_RESULTS_BUCKET}: ${expiration_days}"
    return
  fi

  [[ "$expiration_days" == "None" ]] && expiration_days=""

  echo "  · Bucket: ${ATHENA_RESULTS_BUCKET}"
  echo "  · Expiration (days): ${expiration_days:-<não definido>}"

  if [[ "$expiration_days" == "30" ]]; then
    pass "Check 4 — regra de expiração de 30 dias configurada"
  else
    fail "Check 4 — expiração esperada de 30 dias, encontrado: ${expiration_days:-ausente}"
  fi
}

assume_analytics_role() {
  local creds_line
  creds_line=$(aws sts assume-role \
    --role-arn "$ROLE_ANALYTICS_ARN" \
    --role-session-name "sprint3-validation" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text 2>&1) || {
    echo "$creds_line"
    return 1
  }

  read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<< "$creds_line"
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  return 0
}

run_athena_query() {
  local query_string="$1"
  local database_name="${2:-}"
  local execution_id

  if ! execution_id=$(aws athena start-query-execution \
    --work-group "$WORKGROUP" \
    --query-execution-context "Database=${database_name}" \
    --query-string "$query_string" \
    --query 'QueryExecutionId' \
    --output text 2>&1); then
    echo "START_FAILED|${execution_id}|"
    return
  fi

  local state reason
  local attempts=0
  local max_attempts=60

  while [[ $attempts -lt $max_attempts ]]; do
    state=$(aws athena get-query-execution \
      --query-execution-id "$execution_id" \
      --query 'QueryExecution.Status.State' \
      --output text)

    reason=$(aws athena get-query-execution \
      --query-execution-id "$execution_id" \
      --query 'QueryExecution.Status.StateChangeReason' \
      --output text)

    [[ "$reason" == "None" ]] && reason=""

    if [[ "$state" == "SUCCEEDED" || "$state" == "FAILED" || "$state" == "CANCELLED" ]]; then
      echo "${state}|${reason}|${execution_id}"
      return
    fi

    sleep 2
    attempts=$((attempts + 1))
  done

  echo "TIMEOUT|Query não concluiu em ${max_attempts} tentativas|${execution_id}"
}

check_5_athena_select_vendas() {
  echo
  echo "=== Check 5 — Query Athena com role-analytics (vendas) ==="

  local saved_key saved_secret saved_token
  saved_key="${AWS_ACCESS_KEY_ID:-}"
  saved_secret="${AWS_SECRET_ACCESS_KEY:-}"
  saved_token="${AWS_SESSION_TOKEN:-}"

  local assume_err
  if ! assume_err=$(assume_analytics_role); then
    fail "Check 5 — sts assume-role falhou para role-analytics: ${assume_err}"
    return
  fi

  local query="SELECT product_category_name, ${VENDAS_VALUE_COLUMN} FROM ${VENDAS_DB}.${VENDAS_TABLE} LIMIT 5"
  echo "  · Query: ${query}"

  local result
  result=$(run_athena_query "$query" "$VENDAS_DB")
  local state reason execution_id
  IFS='|' read -r state reason execution_id <<< "$result"

  # Restaura credenciais originais
  if [[ -n "$saved_token" ]]; then
    export AWS_ACCESS_KEY_ID="$saved_key"
    export AWS_SECRET_ACCESS_KEY="$saved_secret"
    export AWS_SESSION_TOKEN="$saved_token"
  else
    export AWS_ACCESS_KEY_ID="$saved_key"
    export AWS_SECRET_ACCESS_KEY="$saved_secret"
    unset AWS_SESSION_TOKEN
  fi

  echo "  · ExecutionId: ${execution_id}"
  echo "  · State: ${state}"
  [[ -n "$reason" ]] && echo "  · Reason: ${reason}"

  if [[ "$state" == "SUCCEEDED" ]]; then
    pass "Check 5 — query em ${VENDAS_DB}.${VENDAS_TABLE} executou sem erro de permissão"
  else
    fail "Check 5 — query esperada SUCCEEDED, obteve ${state}: ${reason}"
  fi
}

check_6_column_access_denied() {
  echo
  echo "=== Check 6 — Column-level security via query (faixa_salarial) ==="

  local saved_key saved_secret saved_token
  saved_key="${AWS_ACCESS_KEY_ID:-}"
  saved_secret="${AWS_SECRET_ACCESS_KEY:-}"
  saved_token="${AWS_SESSION_TOKEN:-}"

  local assume_err
  if ! assume_err=$(assume_analytics_role); then
    fail "Check 6 — sts assume-role falhou para role-analytics: ${assume_err}"
    return
  fi

  local query="SELECT faixa_salarial FROM ${RH_DB}.${RH_TABLE} LIMIT 1"
  echo "  · Query: ${query}"

  local result
  result=$(run_athena_query "$query" "$RH_DB")
  local state reason execution_id
  IFS='|' read -r state reason execution_id <<< "$result"

  if [[ -n "$saved_token" ]]; then
    export AWS_ACCESS_KEY_ID="$saved_key"
    export AWS_SECRET_ACCESS_KEY="$saved_secret"
    export AWS_SESSION_TOKEN="$saved_token"
  else
    export AWS_ACCESS_KEY_ID="$saved_key"
    export AWS_SECRET_ACCESS_KEY="$saved_secret"
    unset AWS_SESSION_TOKEN
  fi

  echo "  · ExecutionId: ${execution_id}"
  echo "  · State: ${state}"
  [[ -n "$reason" ]] && echo "  · Reason: ${reason}"

  local denied=false
  if [[ "$state" == "FAILED" ]]; then
    local reason_lower
    reason_lower=$(echo "$reason" | tr '[:upper:]' '[:lower:]')
    if [[ "$reason_lower" == *"access denied"* \
       || "$reason_lower" == *"permission"* \
       || "$reason_lower" == *"not authorized"* \
       || "$reason_lower" == *"insufficient"* \
       || "$reason_lower" == *"lake formation"* ]]; then
      denied=true
    fi
  fi

  if [[ "$denied" == true ]]; then
    pass "Check 6 — acesso a faixa_salarial negado (column-level security ativo)"
  else
    fail "Check 6 — esperado FAILED com Access Denied; obteve ${state}: ${reason}"
  fi
}

main() {
  require_cmd

  echo "Validação Sprint 3 — Data Mesh"
  echo "Região: ${AWS_REGION}"
  echo "Workgroup: ${WORKGROUP}"
  echo "Bucket resultados: ${ATHENA_RESULTS_BUCKET}"
  echo "Role analytics: ${ROLE_ANALYTICS_ARN}"

  check_1_lf_database_permissions
  check_2_column_level_security
  check_3_athena_workgroup
  check_4_results_bucket_lifecycle
  check_5_athena_select_vendas
  check_6_column_access_denied

  echo
  echo "========================================"
  echo "Resumo: ${PASS_COUNT} PASS, ${FAIL_COUNT} FAIL"
  echo "========================================"

  # Exit 0 somente se checks 1-5 passaram e check 6 confirmou negação de acesso
  if [[ "$FAIL_COUNT" -eq 0 ]]; then
    exit 0
  fi
  exit 1
}

main "$@"
