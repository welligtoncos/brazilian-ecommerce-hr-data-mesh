# Data Mesh — Terraform

Infraestrutura de um **Data Mesh simplificado** na AWS (Vendas + RH), provisionada com Terraform: domínios isolados, consumo governado e consultas analíticas sem expor dados sensíveis.

| Sprint | Entrega |
|--------|---------|
| **Sprint 1** | S3 data lake, IAM roles, Lake Formation, Glue Catalog (`vendas_db`, `rh_db`) |
| **Sprint 2** | Upload de datasets, Glue Jobs ETL, Glue Crawlers |
| **Sprint 3** | Permissões Lake Formation, Athena (`wg-analytics`), column-level security RH |

---

## O que este Data Mesh resolve?

Em muitas empresas, dados de áreas diferentes (vendas, RH, financeiro) ficam em silos: cada time sobe arquivos no S3, cria jobs Glue e tabelas no Catálogo sem padrão comum. Quem consome (BI, analytics, outros times) acaba com **acesso amplo demais** ou **sem acesso nenhum**, e cruzar domínios vira projeto manual e arriscado.

Este repositório modela um cenário típico e mostra como a AWS organiza isso de forma **por domínio**, com **governança centralizada**:

| Problema | Como o projeto aborda |
|----------|------------------------|
| Dados brutos espalhados e sem camada confiável | Dois domínios (`vendas`, `rh`) com prefixos S3 `raw/` → jobs Glue → `refined/` em Parquet |
| Times produtores precisam escrever no lake sem ver dados de outros | Roles IAM por domínio (`role-glue-vendas`, `role-glue-rh`) + grants Lake Formation `ALL` só no próprio database |
| Analytics precisa cruzar vendas e RH sem virar admin do lake | Role consumidora (`role-analytics`): `SELECT` só na tabela agregada de vendas e colunas permitidas de RH |
| Dados sensíveis (ex.: faixa salarial) não podem ir para relatórios gerais | Column-level security no Lake Formation: `faixa_salarial` fora do grant da role-analytics (requer modo LF-only; ver validação E2E) |
| Consultas ad hoc sem padrão de custo/resultado | Workgroup Athena `wg-analytics` com bucket dedicado de resultados e engine v3 |
| Infra repetida e difícil de reproduzir | Tudo como código (Terraform): bucket, roles, LF, jobs, crawlers, tabelas e workgroup |

**Exemplo concreto:** um analista assume `role-analytics`, roda a query cross-domínio (`scripts/queries/cross-domain-vendas-rh.sql`) e obtém receita por categoria de produto cruzada com departamento e satisfação de RH — **sem** acessar salários nem ter permissão de escrita nos domínios produtores.

**O que não é:** um data mesh corporativo completo (federated governance, data products catalog, SLAs por domínio). É um **lab/prova de conceito** didático, alinhado a certificações e workshops AWS (Glue, Lake Formation, Athena).

---

## Arquitetura

```
                         data-mesh-terraform
┌──────────────────────────────────────────────────────────────────┐
│  modules/s3          modules/iam         modules/lakeformation   │
│  · bucket            · role-glue-vendas  · bucket registrado LF   │
│  · prefixos          · role-glue-rh      · settings (read-only)  │
│  · datasets (CSV/py) · role-analytics                            │
├──────────────────────────────────────────────────────────────────┤
│  modules/glue                                                    │
│  · databases vendas_db / rh_db                                   │
│  · jobs: vendas-por-categoria, rh-funcionarios                   │
│  · crawlers: crawler-vendas, crawler-rh                          │
└──────────────────────────────────────────────────────────────────┘
          │                    │                    │
          ▼                    ▼                    ▼
     S3 raw/refined      Glue ETL Jobs         Glue Catalog
                              │                    │
                              └──── Crawlers ──────┘
                                        │
                                   Athena (wg-analytics)
```

### Fluxo operacional (após `terraform apply`)

```
1. CSVs + scripts  →  S3 (raw/ e scripts/)
2. Glue Jobs       →  S3 (refined/ em Parquet)
3. Glue Crawlers   →  Glue Catalog (tabelas)
4. Athena          →  queries analíticas (role-analytics + LF)
```

### Prefixos S3

| Prefixo | Uso |
|---------|-----|
| `dominio=vendas/raw/order_items/` | CSV Olist — order items |
| `dominio=vendas/raw/products/` | CSV Olist — products |
| `dominio=vendas/refined/vendas_por_categoria/` | Saída ETL Vendas (Parquet) |
| `dominio=rh/raw/funcionarios/` | CSV IBM HR Attrition |
| `dominio=rh/refined/funcionarios/` | Saída ETL RH (Parquet) |
| `scripts/` | Scripts PySpark dos Glue Jobs |
| `athena-results/` | Resultados de queries Athena |

---

## Pré-requisitos

### Software

| Ferramenta | Versão mínima | Verificação |
|------------|---------------|-------------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5 | `terraform version` |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 | `aws --version` |
| PowerShell ou Bash | — | terminal com acesso à AWS |

### Credenciais AWS

```powershell
aws configure
# ou
aws configure --profile data-mesh
$env:AWS_PROFILE = "data-mesh"
```

Permissões mínimas para o Terraform:

- S3, IAM, Glue (databases, jobs, crawlers)
- `lakeformation:RegisterResource`, `lakeformation:GetDataLakeSettings`

> **Lake Formation:** a policy `AWSLakeFormationDataAdmin` **nega** `lakeformation:PutDataLakeSettings`. Este projeto lê as settings existentes e registra o bucket — não altera admins via Terraform. Se LF ainda não foi configurado, um **account root** deve definir o data lake admin no Console uma vez.

---

## Estrutura do projeto

```
data-mesh-terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars
├── README.md
├── data/                              # arquivos locais enviados ao S3
│   ├── olist_order_items_dataset.csv
│   ├── olist_products_dataset.csv
│   ├── WA_Fn-UseC_-HR-Employee-Attrition.csv
│   ├── job_vendas_por_categoria.py
│   └── job_rh_funcionarios.py
└── modules/
    ├── s3/
    │   ├── main.tf                    # bucket, encryption, prefixos
    │   ├── datasets.tf                # upload CSV + scripts
    │   ├── variables.tf
    │   └── outputs.tf
    ├── iam/                           # roles Glue + analytics
    ├── lakeformation/                 # registro do bucket
    ├── glue/
    │   ├── catalog.tf                 # vendas_db, rh_db
    │   ├── job.tf                     # Glue Jobs ETL
    │   ├── crawler.tf                 # Glue Crawlers
    │   ├── variables.tf
    │   └── outputs.tf
    └── athena/                        # workgroup + bucket de resultados
```

---

## Instalação

### 1. Prepare os datasets

Coloque os arquivos em `data/`. O repositório inclui **CSVs de amostra** (1 linha); substitua pelos datasets reais:

| Arquivo local | Origem |
|---------------|--------|
| `olist_order_items_dataset.csv` | [Olist Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) |
| `olist_products_dataset.csv` | mesmo dataset |
| `WA_Fn-UseC_-HR-Employee-Attrition.csv` | [IBM HR Kaggle](https://www.kaggle.com/datasets/pavansubhasht/ibm-hr-analytics-attrition-label) |

### 2. Configure variáveis

Edite `terraform.tfvars`:

```hcl
aws_region   = "us-east-1"
bucket_name  = "meu-datalake-mesh"   # globalmente único no S3
project_name = "data-mesh"
environment  = "dev"
```

Se o bucket já existir na conta, importe-o (ver [Troubleshooting](#troubleshooting)).

### 3. Deploy com Terraform

```powershell
cd C:\welligton-aws\project-glue\data-mesh-terraform

terraform init
terraform validate
terraform plan "-out=plan.out"
terraform apply "plan.out"
terraform output
```

> **PowerShell:** use aspas em `-out=plan.out` e `"plan.out"` no apply.

Na primeira execução completa (Sprint 1 + 2), espere ~33 recursos gerenciados.

---

## Operação pós-deploy

O Terraform provisiona a infraestrutura; **jobs e crawlers rodam manualmente** (ou via CI).

### 1. Reenviar dados após trocar CSVs

```powershell
terraform plan "-out=plan.out"
terraform apply "plan.out"
```

O Terraform detecta mudanças via `filemd5()` e atualiza os objetos no S3.

### 2. Executar Glue Jobs

```powershell
aws glue start-job-run --job-name vendas-por-categoria
aws glue start-job-run --job-name rh-funcionarios
```

Acompanhar:

```powershell
aws glue get-job-runs --job-name vendas-por-categoria --max-results 1
aws glue get-job-runs --job-name rh-funcionarios --max-results 1
```

Esperado: `"JobRunState": "SUCCEEDED"`.

### 3. Executar Crawlers (após jobs concluírem)

```powershell
aws glue start-crawler --name crawler-vendas
aws glue start-crawler --name crawler-rh
```

Verificar tabelas catalogadas:

```powershell
aws glue get-tables --database-name vendas_db
aws glue get-tables --database-name rh_db
```

### 4. Consultar no Athena (Sprint 3)

Após os crawlers, use o Console Athena ou CLI. Os nomes das tabelas dependem do que o crawler inferir a partir do Parquet.

---

## Outputs do Terraform

| Output | Descrição |
|--------|-----------|
| `bucket_name` / `bucket_arn` | Bucket S3 do data lake |
| `role_glue_vendas_arn` | Role IAM — Glue Vendas |
| `role_glue_rh_arn` | Role IAM — Glue RH |
| `role_analytics_arn` | Role IAM — consumo Athena |
| `vendas_db_name` / `rh_db_name` | Databases Glue Catalog |
| `glue_job_vendas_name` | Job `vendas-por-categoria` |
| `glue_job_rh_name` | Job `rh-funcionarios` |
| `crawler_vendas_name` | Crawler `crawler-vendas` |
| `crawler_rh_name` | Crawler `crawler-rh` |

---

## Validação

Este projeto **não inclui testes automatizados** (Terratest, Checkov, etc.). A validação é manual:

### Infraestrutura (Terraform)

```powershell
terraform validate    # sintaxe HCL
terraform plan        # drift — esperado: No changes
```

### Funcional (AWS CLI)

| Check | Comando | Esperado |
|-------|---------|----------|
| CSVs no S3 | `aws s3 ls s3://meu-datalake-mesh/dominio=vendas/raw/ --recursive` | 2 CSVs Olist |
| Parquet refinado | `aws s3 ls s3://meu-datalake-mesh/dominio=vendas/refined/ --recursive` | `.parquet` |
| Jobs OK | `aws glue get-job-runs --job-name vendas-por-categoria --max-results 1` | `SUCCEEDED` |
| LF registrado | `aws lakeformation list-resources` | ARN do bucket |
| Tabelas catalogadas | `aws glue get-tables --database-name vendas_db` | ≥ 1 tabela (após crawler) |

---

## Troubleshooting

### `Error: Too many command line arguments` (PowerShell)

```powershell
terraform plan "-out=plan.out"
terraform apply "plan.out"
```

### `Error: Saved plan is stale`

O `plan.out` ficou desatualizado após mudança no state. Gere um plano novo:

```powershell
terraform plan "-out=plan.out"
terraform apply "plan.out"
```

Se aparecer `No changes`, a infra já está sincronizada — não é necessário apply.

### `BucketAlreadyExists`

Bucket existe na AWS, mas não no state do Terraform:

```powershell
terraform import module.s3.aws_s3_bucket.datalake meu-datalake-mesh
terraform plan "-out=plan.out"
terraform apply "plan.out"
```

### `AccessDeniedException: lakeformation:PutDataLakeSettings`

A policy `AWSLakeFormationDataAdmin` nega essa ação por design. O módulo `lakeformation` usa `data "aws_lakeformation_data_lake_settings"` (read-only). Confirme que `modules/lakeformation/main.tf` **não** contém `resource "aws_lakeformation_data_lake_settings"`.

### Crawler: `Unsupported option CombineSimilarSchemas`

O valor correto na API do Glue é `CombineCompatibleSchemas`:

```hcl
configuration = jsonencode({
  Version = 1.0
  Grouping = {
    TableGroupingPolicy = "CombineCompatibleSchemas"
  }
})
```

---

## Validação E2E (scripts)

No **Git Bash**, use caminho Unix (não `cd c:\...`):

```bash
cd /c/welligton-aws/project-glue/data-mesh-terraform
bash scripts/validate-e2e.sh
bash scripts/run-cross-domain-query.sh
```

| Sintoma | Causa | Ação |
|---------|--------|------|
| S3/Glue/workgroup `[FAIL]` com tudo existindo | Terminal com credenciais da `role-analytics` | `unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN` ou abra terminal novo |
| `AssumeRole` negado na própria role-analytics | Mesma sessão já assumida | Normal — o script detecta e pula; use usuário IAM para seções 2–6 |
| `faixa_salarial` acessível no Athena | `IAM_ALLOWED_PRINCIPALS` nos defaults do LF | Rode como **root**: `bash scripts/enable-lakeformation-only-mode.sh` |

---

## Destruir a infraestrutura

```powershell
terraform destroy
```

> Remove bucket, roles, jobs, crawlers, databases e registro no Lake Formation.

---

## Referência rápida

```powershell
# Ciclo Terraform
terraform init
terraform validate
terraform plan "-out=plan.out"
terraform apply "plan.out"
terraform output
terraform state list

# Pipeline operacional
aws glue start-job-run --job-name vendas-por-categoria
aws glue start-job-run --job-name rh-funcionarios
aws glue start-crawler --name crawler-vendas
aws glue start-crawler --name crawler-rh
```

---

## Sprint 3 (aplicado)

- Workgroup Athena `wg-analytics` + bucket de resultados
- Lake Formation: produtores, `role-analytics` (tabela vendas + colunas RH)
- Scripts: `validate-e2e.sh`, `validate-sprint3.sh`, `run-cross-domain-query.sh`
- Column-level em `rh_db.funcionarios` exige modo LF-only (sem `IAM_ALLOWED_PRINCIPALS`)

---

## Variáveis

| Variável | Default | Descrição |
|----------|---------|-----------|
| `aws_region` | `us-east-1` | Região AWS |
| `bucket_name` | `meu-datalake-mesh` | Nome do bucket (único globalmente) |
| `project_name` | `data-mesh` | Tags e naming |
| `environment` | `dev` | Tags e naming |

## Tags padrão

```
Project     = data-mesh
Environment = dev
Domain      = vendas | rh   (recursos por domínio)
```

Definidas via `default_tags` no provider (`versions.tf`) e reforçadas nos módulos.
