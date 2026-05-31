# Data Mesh — Sprint 1 (Terraform)

Infraestrutura base de um Data Mesh simplificado na AWS, com:

- **S3** — data lake com prefixos por domínio
- **IAM** — roles para Glue (Vendas/RH) e consumo analítico (Athena)
- **Lake Formation** — registro do bucket no catálogo governado
- **Glue Catalog** — databases `vendas_db` e `rh_db`

> O módulo `athena/` já existe na estrutura, mas será conectado na Sprint 2.

---

## Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                     data-mesh-terraform                      │
├──────────┬──────────┬────────────────┬──────────────────────┤
│  module  │  module  │    module      │      module          │
│   s3     │   iam    │ lakeformation  │       glue           │
├──────────┴──────────┴────────────────┴──────────────────────┤
│  S3 Bucket (dominio=vendas/, dominio=rh/, scripts/, ...)    │
│  IAM Roles: glue-vendas, glue-rh, analytics                 │
│  LF: bucket registrado + settings lidas (read-only)         │
│  Glue Catalog: vendas_db, rh_db                             │
└─────────────────────────────────────────────────────────────┘
```

### Prefixos S3 criados

| Prefixo | Uso |
|---------|-----|
| `dominio=vendas/raw/order_items/` | Dados brutos Olist — order items |
| `dominio=vendas/raw/products/` | Dados brutos Olist — products |
| `dominio=vendas/refined/` | Camada refinada do domínio Vendas |
| `dominio=rh/raw/` | Dados brutos IBM HR Attrition |
| `dominio=rh/refined/` | Camada refinada do domínio RH |
| `scripts/` | Scripts PySpark dos Glue Jobs |
| `athena-results/` | Resultados de queries Athena |

---

## Pré-requisitos

### Software

| Ferramenta | Versão mínima | Verificação |
|------------|---------------|-------------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.5 | `terraform version` |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 recomendado | `aws --version` |
| PowerShell ou Bash | — | terminal com acesso à AWS |

### Credenciais AWS

Configure um perfil ou variáveis de ambiente com permissões para criar:

- S3, IAM, Glue Catalog, Lake Formation

Exemplo com AWS CLI:

```bash
aws configure
# ou
aws configure --profile data-mesh
```

Com perfil nomeado, exporte antes de rodar o Terraform:

```powershell
# PowerShell
$env:AWS_PROFILE = "data-mesh"
```

```bash
# Bash
export AWS_PROFILE=data-mesh
```

### Permissões IAM recomendadas

O usuário/role que executa o Terraform precisa, no mínimo:

- `s3:*` (bucket e objetos)
- `iam:CreateRole`, `iam:PutRolePolicy`, `iam:AttachRolePolicy`
- `glue:CreateDatabase`
- `lakeformation:RegisterResource`, `lakeformation:GetDataLakeSettings`

> **Lake Formation — ponto importante:** a policy gerenciada `AWSLakeFormationDataAdmin` **nega explicitamente** `lakeformation:PutDataLakeSettings`. Por isso, este projeto **não tenta alterar** os admins do Lake Formation via Terraform — apenas lê as settings existentes e registra o bucket S3.

Se o Lake Formation ainda não foi configurado na conta, um **administrator/root** deve definir o data lake admin uma vez pelo Console AWS:

1. Lake Formation → **Administrative roles and tasks** → **Data lake administrators**
2. Adicionar o usuário/role que executará o projeto

---

## Instalação e deploy

### 1. Clone ou acesse o diretório do projeto

```powershell
cd C:\welligton-aws\project-glue\data-mesh-terraform
```

### 2. Configure as variáveis

Edite `terraform.tfvars`:

```hcl
aws_region   = "us-east-1"
bucket_name  = "meu-datalake-mesh"   # deve ser globalmente único no S3
project_name = "data-mesh"
environment  = "dev"
```

**Dica:** se o nome do bucket já existir (na sua conta ou em outra), use um sufixo único:

```hcl
bucket_name = "meu-datalake-mesh-303238378103"
```

### 3. Inicialize o Terraform

```powershell
terraform init
```

### 4. Valide a configuração

```powershell
terraform validate
```

### 5. Gere o plano de execução

```powershell
# PowerShell — use aspas no -out (ver seção Troubleshooting)
terraform plan "-out=plan.out"
```

Revise o plano. Na primeira execução, espere a criação de ~22 recursos.

### 6. Aplique a infraestrutura

```powershell
terraform apply "plan.out"
```

Ou, sem salvar plano:

```powershell
terraform apply
```

### 7. Confira os outputs

```powershell
terraform output
```

Saída esperada:

| Output | Descrição |
|--------|-----------|
| `bucket_name` | Nome do bucket S3 |
| `bucket_arn` | ARN do bucket |
| `role_glue_vendas_arn` | Role IAM para Glue Jobs do domínio Vendas |
| `role_glue_rh_arn` | Role IAM para Glue Jobs do domínio RH |
| `role_analytics_arn` | Role IAM para consumo via Athena |
| `vendas_db_name` | Database Glue `vendas_db` |
| `rh_db_name` | Database Glue `rh_db` |

---

## Estrutura do projeto

```
data-mesh-terraform/
├── main.tf                 # Orquestração dos módulos
├── variables.tf            # Variáveis raiz
├── outputs.tf              # Outputs raiz
├── versions.tf             # Terraform >= 1.5, AWS provider >= 5.0
├── terraform.tfvars        # Valores das variáveis (customize aqui)
├── README.md
└── modules/
    ├── s3/                 # Bucket, encryption, versioning, prefixos
    ├── iam/                # Roles Glue + analytics
    ├── lakeformation/      # Registro do bucket no LF
    ├── glue/               # Databases vendas_db e rh_db
    └── athena/             # Sprint 2 — ainda não conectado no main.tf
```

---

## Verificação pós-deploy

### S3 — prefixos criados

```powershell
aws s3 ls s3://meu-datalake-mesh/ --recursive
```

### IAM — roles criadas

```powershell
aws iam get-role --role-name data-mesh-role-glue-vendas-dev
aws iam get-role --role-name data-mesh-role-glue-rh-dev
aws iam get-role --role-name data-mesh-role-analytics-dev
```

### Glue Catalog — databases

```powershell
aws glue get-database --name vendas_db
aws glue get-database --name rh_db
```

### Lake Formation — bucket registrado

```powershell
aws lakeformation list-resources
```

Deve listar `arn:aws:s3:::meu-datalake-mesh`.

### Lake Formation — admins (somente leitura)

```powershell
aws lakeformation get-data-lake-settings
```

---

## Troubleshooting

### `Error: Too many command line arguments` (PowerShell)

O PowerShell interpreta `-out=plan.out` como parâmetro próprio. Use aspas:

```powershell
terraform plan "-out=plan.out"
terraform apply "plan.out"
```

Alternativas:

```powershell
terraform plan -out plan.out
terraform -- plan -out=plan.out
```

### `BucketAlreadyExists`

O bucket já existe na AWS, mas não está no state do Terraform.

**Se o bucket é seu** (mesma conta), importe-o:

```powershell
terraform import module.s3.aws_s3_bucket.datalake meu-datalake-mesh
terraform plan "-out=plan.out"
terraform apply "plan.out"
```

**Se o nome está ocupado por outra conta**, altere `bucket_name` em `terraform.tfvars` e rode `plan` + `apply` novamente.

> Nunca reutilize um `plan.out` gerado **antes** de um import ou mudança de state. Sempre gere um plano novo.

### `AccessDeniedException: lakeformation:PutDataLakeSettings`

**Causa:** a policy `AWSLakeFormationDataAdmin` contém um **Deny explícito** em `PutDataLakeSettings`. Isso é comportamento intencional da AWS.

**Solução aplicada neste projeto:** o módulo `lakeformation` usa `data "aws_lakeformation_data_lake_settings"` (somente leitura) em vez de tentar criar/alterar settings.

Se você ainda vê o erro com `aws_lakeformation_data_lake_settings.this`, seu código local está desatualizado. Confirme que `modules/lakeformation/main.tf` contém:

```hcl
data "aws_lakeformation_data_lake_settings" "current" {}

resource "aws_lakeformation_resource" "datalake" {
  arn                     = var.bucket_arn
  use_service_linked_role = true
}
```

Depois:

```powershell
terraform plan "-out=plan.out"
terraform apply "plan.out"
```

### Plano mostra recursos a criar, mas apply falha com erro antigo

Você provavelmente aplicou um `plan.out` **desatualizado**. Sempre:

```powershell
terraform plan "-out=plan.out"
terraform apply "plan.out"
```

---

## Destruir a infraestrutura

> **Atenção:** remove bucket, roles, databases e registro no Lake Formation.

```powershell
terraform destroy
```

Para preservar os dados no S3, esvazie manualmente o bucket ou remova o módulo S3 do destroy com `-target` (uso avançado).

---

## Referência rápida de comandos

```powershell
# Ciclo completo
terraform init
terraform validate
terraform plan "-out=plan.out"
terraform apply "plan.out"
terraform output

# Ver state
terraform state list

# Formatar arquivos .tf
terraform fmt -recursive
```

---

## Próximos passos (Sprint 2)

Os outputs desta sprint serão referenciados nos Glue Jobs:

```hcl
module.s3.bucket_name
module.s3.bucket_arn
module.iam.role_glue_vendas_arn
module.iam.role_glue_rh_arn
module.glue.vendas_db_name
module.glue.rh_db_name
```

Também será conectado o módulo `athena/` para workgroup de queries analíticas.

---

## Variáveis disponíveis

| Variável | Default | Descrição |
|----------|---------|-----------|
| `aws_region` | `us-east-1` | Região AWS |
| `bucket_name` | `meu-datalake-mesh` | Nome do bucket S3 (único globalmente) |
| `project_name` | `data-mesh` | Nome do projeto (tags e naming) |
| `environment` | `dev` | Ambiente (tags e naming) |

---

## Tags padrão

Todos os recursos recebem:

```
Project     = data-mesh
Environment = dev
```

Definidas via `default_tags` no provider AWS (`versions.tf`) e reforçadas nos módulos.
