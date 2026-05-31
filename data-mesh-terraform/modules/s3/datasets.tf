# Domínio Vendas — datasets Olist
resource "aws_s3_object" "olist_order_items" {
  bucket = aws_s3_bucket.datalake.id
  key    = "dominio=vendas/raw/order_items/olist_order_items_dataset.csv"
  source = "${path.root}/data/olist_order_items_dataset.csv"
  etag   = filemd5("${path.root}/data/olist_order_items_dataset.csv")

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Domain      = "vendas"
  }
}

resource "aws_s3_object" "olist_products" {
  bucket = aws_s3_bucket.datalake.id
  key    = "dominio=vendas/raw/products/olist_products_dataset.csv"
  source = "${path.root}/data/olist_products_dataset.csv"
  etag   = filemd5("${path.root}/data/olist_products_dataset.csv")

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Domain      = "vendas"
  }
}

# Domínio RH — dataset IBM HR Attrition
resource "aws_s3_object" "hr_employee_attrition" {
  bucket = aws_s3_bucket.datalake.id
  key    = "dominio=rh/raw/funcionarios/WA_Fn-UseC_-HR-Employee-Attrition.csv"
  source = "${path.root}/data/WA_Fn-UseC_-HR-Employee-Attrition.csv"
  etag   = filemd5("${path.root}/data/WA_Fn-UseC_-HR-Employee-Attrition.csv")

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Domain      = "rh"
  }
}

# Scripts — Glue Jobs
resource "aws_s3_object" "job_vendas_por_categoria" {
  bucket = aws_s3_bucket.datalake.id
  key    = "scripts/job_vendas_por_categoria.py"
  source = "${path.root}/data/job_vendas_por_categoria.py"
  etag   = filemd5("${path.root}/data/job_vendas_por_categoria.py")

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Domain      = "vendas"
  }
}

resource "aws_s3_object" "job_rh_funcionarios" {
  bucket = aws_s3_bucket.datalake.id
  key    = "scripts/job_rh_funcionarios.py"
  source = "${path.root}/data/job_rh_funcionarios.py"
  etag   = filemd5("${path.root}/data/job_rh_funcionarios.py")

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Domain      = "rh"
  }
}
