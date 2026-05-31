resource "terraform_data" "script_vendas_uploaded" {
  input = var.glue_script_vendas_id
}

resource "terraform_data" "script_rh_uploaded" {
  input = var.glue_script_rh_id
}

resource "aws_glue_job" "vendas_por_categoria" {
  name     = "vendas-por-categoria"
  role_arn = var.role_glue_vendas_arn

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 10
  max_retries       = 0

  command {
    name            = "glueetl"
    script_location = "s3://${var.bucket_name}/scripts/job_vendas_por_categoria.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--INPUT_PATH"                       = "s3://${var.bucket_name}/dominio=vendas/raw/"
    "--OUTPUT_PATH"                      = "s3://${var.bucket_name}/dominio=vendas/refined/vendas_por_categoria/"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Domain      = "vendas"
  }

  depends_on = [terraform_data.script_vendas_uploaded]
}

resource "aws_glue_job" "rh_funcionarios" {
  name     = "rh-funcionarios"
  role_arn = var.role_glue_rh_arn

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 10
  max_retries       = 0

  command {
    name            = "glueetl"
    script_location = "s3://${var.bucket_name}/scripts/job_rh_funcionarios.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--INPUT_PATH"                       = "s3://${var.bucket_name}/dominio=rh/raw/"
    "--OUTPUT_PATH"                      = "s3://${var.bucket_name}/dominio=rh/refined/funcionarios/"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Domain      = "rh"
  }

  depends_on = [terraform_data.script_rh_uploaded]
}
