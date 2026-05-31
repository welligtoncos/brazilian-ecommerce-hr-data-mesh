resource "aws_glue_crawler" "vendas" {
  name          = "crawler-vendas"
  role          = var.role_glue_vendas_arn
  database_name = var.vendas_db_name

  s3_target {
    path = "s3://${var.bucket_name}/dominio=vendas/refined/"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Domain      = "vendas"
  }
}

resource "aws_glue_crawler" "rh" {
  name          = "crawler-rh"
  role          = var.role_glue_rh_arn
  database_name = var.rh_db_name

  s3_target {
    path = "s3://${var.bucket_name}/dominio=rh/refined/"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Domain      = "rh"
  }
}
