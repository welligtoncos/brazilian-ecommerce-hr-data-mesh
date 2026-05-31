#!/usr/bin/env bash
# Validação ponta a ponta do Data Mesh (Sprints 1–3)
#
# Uso (Git Bash / WSL):
#   cd /c/welligton-aws/project-glue/data-mesh-terraform
#   bash scripts/validate-e2e.sh
#
# Requisitos: aws CLI
#   · Seções 2–6: usuário IAM (ex.: usuario-dados), NÃO role-analytics
#   · Seção 7: usuário IAM ou sessão já assumida na role-analytics
#
# Se você rodou assume-role antes neste terminal:
#   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-data-mesh}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
BUCKET="${BUCKET:-meu-datalake-mesh}"
WORKGROUP="${WORKGROUP:-wg-analytics}"
ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)}"
ROLE_ANALYTICS="arn:aws:iam::${ACCOUNT_ID}:role/${PROJECT_NAME}-role-analytics-${ENVIRONMENT}"

export AWS_DEFAULT_REGION="$AWS_REGION"
export AWS_REGION="$AWS_REGION"

PASS=0
FAIL=0
WARN=0
SKIP=0

ok()   { PASS=$((PASS + 1)); echo "[OK]   $1"; }
bad()  { FAIL=$((FAIL + 1)); echo "[FAIL] $1"; }
warn() { WARN=$((WARN + 1)); echo "[WARN] $1"; }
skip() { SKIP=$((SKIP + 1)); echo "[SKIP] $1"; }

section() { echo; echo "========== $1 =========="; }

is_analytics_role_session() {
  local caller_arn
  caller_arn=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "")
  [[ "$caller_arn" == *":assumed-role/${PROJECT_NAME}-role-analytics-${ENVIRONMENT}/"* ]] \
    || [[ "$caller_arn" == "$ROLE_ANALYTICS" ]]
}

require_iam_user_for_infra() {
  if is_analytics_role_session; then
    skip "$1 (sessão atual é role-analytics — use usuário IAM: unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN)"
    return 1
  fi
  return 0
}

section "0. Identidade AWS"
caller=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "desconhecido")
echo "Caller: ${caller}"
if is_analytics_role_session; then
  warn "Sessão role-analytics detectada — checks S3/Glue/workgroup (2–6) serão ignorados"
  echo "  Para validação completa, abra terminal novo ou:"
  echo "  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN"
else
  ok "sessão IAM de usuário (adequada para checks de infra)"
fi

section "1. Infraestrutura Terraform"
if terraform -chdir="$ROOT_DIR" validate >/dev/null 2>&1; then
  ok "terraform validate"
else
  bad "terraform validate"
fi

section "2. S3 — dados e scripts"
if require_iam_user_for_infra "bloco S3"; then
  for key in \
    "dominio=vendas/raw/order_items/olist_order_items_dataset.csv" \
    "dominio=vendas/raw/products/olist_products_dataset.csv" \
    "dominio=rh/raw/funcionarios/WA_Fn-UseC_-HR-Employee-Attrition.csv" \
    "scripts/job_vendas_por_categoria.py" \
    "scripts/job_rh_funcionarios.py"; do
    if aws s3api head-object --bucket "$BUCKET" --key "$key" >/dev/null 2>&1; then
      ok "s3://${BUCKET}/${key}"
    else
      bad "objeto ausente: s3://${BUCKET}/${key} (rode: terraform apply -target=module.s3)"
    fi
  done
fi

section "3. Glue Jobs — última execução"
if require_iam_user_for_infra "bloco Glue jobs"; then
  for job in vendas-por-categoria rh-funcionarios; do
    state=$(aws glue get-job-runs --job-name "$job" --max-results 1 \
      --query "JobRuns[0].JobRunState" --output text 2>/dev/null || echo "UNKNOWN")
    if [[ "$state" == "SUCCEEDED" ]]; then
      ok "job ${job}: ${state}"
    elif [[ "$state" == "RUNNING" ]]; then
      warn "job ${job}: ainda RUNNING — aguarde e rode o script de novo"
    else
      bad "job ${job}: ${state} (rode: aws glue start-job-run --job-name ${job})"
    fi
  done
fi

section "4. S3 refined — Parquet"
if require_iam_user_for_infra "bloco Parquet refined"; then
  if aws s3 ls "s3://${BUCKET}/dominio=vendas/refined/vendas_por_categoria/" 2>/dev/null | grep -qiE 'parquet|\.parquet'; then
    ok "Parquet vendas em refined/"
  else
    bad "sem Parquet em dominio=vendas/refined/vendas_por_categoria/ (rode job vendas-por-categoria)"
  fi
  if aws s3 ls "s3://${BUCKET}/dominio=rh/refined/funcionarios/" 2>/dev/null | grep -qiE 'parquet|\.parquet'; then
    ok "Parquet RH em refined/funcionarios/"
  else
    bad "sem Parquet em dominio=rh/refined/funcionarios/ (rode job rh-funcionarios)"
  fi
fi

section "5. Glue Catalog — tabelas"
for spec in "vendas_db:vendas_por_categoria" "rh_db:funcionarios"; do
  db="${spec%%:*}"
  tbl="${spec##*:}"
  if aws glue get-table --database-name "$db" --name "$tbl" >/dev/null 2>&1; then
    ok "tabela ${db}.${tbl}"
  else
    warn "tabela ${db}.${tbl} ausente — rode os crawlers"
  fi
done

section "6. Athena workgroup"
if require_iam_user_for_infra "bloco Athena workgroup"; then
  wg_state=$(aws athena get-work-group --work-group "$WORKGROUP" \
    --query "WorkGroup.State" --output text 2>/dev/null || echo "MISSING")
  if [[ "$wg_state" == "ENABLED" ]]; then
    ok "workgroup ${WORKGROUP} ENABLED"
  else
    bad "workgroup ${WORKGROUP}: ${wg_state} (rode: terraform apply -target=module.athena)"
  fi
fi

lf_iam_allowed_principals_active() {
  aws lakeformation get-data-lake-settings --output json 2>/dev/null \
    | grep -q 'IAM_ALLOWED_PRINCIPALS' || return 1
}

section "7. Lake Formation + Athena (role-analytics)"

IAM_ALLOWED_ACTIVE=false
if lf_iam_allowed_principals_active; then
  IAM_ALLOWED_ACTIVE=true
  warn "IAM_ALLOWED_PRINCIPALS ativo — column-level pode não bloquear colunas negadas"
  echo "  Corrija com usuário root: bash scripts/enable-lakeformation-only-mode.sh"
fi

assume_analytics_if_needed() {
  if is_analytics_role_session; then
    ok "já em sessão role-analytics — pulando AssumeRole"
    return 0
  fi
  local creds
  if ! creds=$(aws sts assume-role \
    --role-arn "$ROLE_ANALYTICS" \
    --role-session-name "e2e-validate" \
    --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
    --output text 2>&1); then
    bad "sts:AssumeRole na role-analytics: ${creds}"
    echo "  Dica: adicione policy sts:AssumeRole no usuário IAM para ${ROLE_ANALYTICS}"
    return 1
  fi
  ok "sts:AssumeRole na role-analytics"
  read -r AK SK ST <<< "$creds"
  export AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_SESSION_TOKEN="$ST"
  ASSUMED_FOR_SECTION7=true
  return 0
}

ASSUMED_FOR_SECTION7=false

if assume_analytics_if_needed; then
  run_athena() {
    local label="$1"
    local sql="$2"
    local eid
    eid=$(aws athena start-query-execution \
      --work-group "$WORKGROUP" \
      --query-string "$sql" \
      --query QueryExecutionId --output text) || { bad "${label}: start falhou"; return; }
    local i=0 state reason
    while [[ $i -lt 45 ]]; do
      state=$(aws athena get-query-execution --query-execution-id "$eid" \
        --query "QueryExecution.Status.State" --output text)
      reason=$(aws athena get-query-execution --query-execution-id "$eid" \
        --query "QueryExecution.Status.StateChangeReason" --output text)
      [[ "$reason" == "None" ]] && reason=""
      [[ "$state" != "RUNNING" && "$state" != "QUEUED" ]] && break
      sleep 2
      i=$((i + 1))
    done
    if [[ "$state" == "SUCCEEDED" ]]; then
      ok "${label} (QueryExecutionId=${eid})"
    else
      bad "${label}: ${state} ${reason}"
    fi
  }

  run_athena "SELECT vendas" \
    "SELECT product_category_name, total_receita, qtd_itens FROM vendas_db.vendas_por_categoria LIMIT 5"

  run_athena "SELECT rh (colunas permitidas)" \
    "SELECT departamento, satisfacao, employee_id FROM rh_db.funcionarios LIMIT 5"

  # Column-level: query em coluna negada deve FALHAR
  eid_cls=$(aws athena start-query-execution \
    --work-group "$WORKGROUP" \
    --query-string "SELECT faixa_salarial FROM rh_db.funcionarios LIMIT 1" \
    --query QueryExecutionId --output text 2>/dev/null || true)
  if [[ -z "${eid_cls:-}" ]]; then
    ok "faixa_salarial negada (start-query falhou)"
  else
    i=0
    state_cls="RUNNING"
    while [[ $i -lt 45 ]]; do
      state_cls=$(aws athena get-query-execution --query-execution-id "$eid_cls" \
        --query "QueryExecution.Status.State" --output text)
      [[ "$state_cls" != "RUNNING" && "$state_cls" != "QUEUED" ]] && break
      sleep 2
      i=$((i + 1))
    done
    if [[ "$state_cls" == "SUCCEEDED" ]]; then
      if [[ "$IAM_ALLOWED_ACTIVE" == "true" ]]; then
        warn "faixa_salarial acessível (IAM_ALLOWED_PRINCIPALS ignora LF column-level)"
      else
        bad "faixa_salarial deveria ser negada mas query passou"
      fi
    else
      ok "faixa_salarial negada (estado ${state_cls})"
    fi
  fi

  if [[ "${ASSUMED_FOR_SECTION7:-false}" == "true" ]]; then
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  fi
fi

section "Resumo"
echo "OK: ${PASS}  FAIL: ${FAIL}  WARN: ${WARN}  SKIP: ${SKIP}"
echo
if [[ $FAIL -eq 0 ]]; then
  if [[ $SKIP -gt 0 ]]; then
    echo "Validação parcial (itens SKIP). Para E2E completo, rode com usuário IAM e depois:"
  else
    echo "Fluxo base validado. Próximo passo opcional:"
  fi
  echo "  bash scripts/run-cross-domain-query.sh"
  exit 0
fi
echo "Corrija os itens [FAIL] e rode novamente."
exit 1
