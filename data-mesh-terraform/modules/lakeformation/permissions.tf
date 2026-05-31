# === Produtores ===

resource "aws_lakeformation_permissions" "glue_vendas_db" {
  principal   = var.role_glue_vendas_arn
  permissions = ["ALL"]

  database {
    name = var.vendas_db_name
  }

  depends_on = [aws_lakeformation_resource.datalake]
}

resource "aws_lakeformation_permissions" "produtor_vendas_location" {
  principal   = var.role_glue_vendas_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = "arn:aws:s3:::${var.bucket_name}/dominio=vendas/"
  }

  depends_on = [aws_lakeformation_resource.datalake]
}

resource "aws_lakeformation_permissions" "produtor_rh_db" {
  principal   = var.role_glue_rh_arn
  permissions = ["ALL"]

  database {
    name = var.rh_db_name
  }

  depends_on = [aws_lakeformation_resource.datalake]
}

resource "aws_lakeformation_permissions" "produtor_rh_location" {
  principal   = var.role_glue_rh_arn
  permissions = ["DATA_LOCATION_ACCESS"]

  data_location {
    arn = "arn:aws:s3:::${var.bucket_name}/dominio=rh/"
  }

  depends_on = [aws_lakeformation_resource.datalake]
}

# === Consumidor Analytics ===

resource "aws_lakeformation_permissions" "analytics_vendas_view" {
  principal   = var.role_analytics_arn
  permissions = ["SELECT"]

  table {
    database_name = var.vendas_db_name
    name          = "vendas_por_categoria"
  }

  depends_on = [aws_lakeformation_resource.datalake]
}

# Colunas permitidas para role-analytics (faixa_salarial excluída = column-level security)
resource "aws_lakeformation_permissions" "analytics_rh_columns" {
  principal   = var.role_analytics_arn
  permissions = ["SELECT"]

  table_with_columns {
    database_name = var.rh_db_name
    name          = "funcionarios"
    column_names = [
      "employee_id",
      "departamento",
      "cargo",
      "idade",
      "genero",
      "anos_empresa",
      "satisfacao",
      "rotatividade",
      "total_funcionarios",
      "total_saidas",
      "media_satisfacao",
      "media_anos_empresa",
      "data_carga",
    ]
  }

  depends_on = [aws_lakeformation_resource.datalake]
}

# === Crawlers ===

resource "aws_lakeformation_permissions" "crawler_vendas_catalog" {
  principal   = var.role_glue_vendas_arn
  permissions = ["CREATE_TABLE", "ALTER", "DROP"]

  database {
    name = var.vendas_db_name
  }

  depends_on = [aws_lakeformation_resource.datalake]
}

resource "aws_lakeformation_permissions" "crawler_rh_catalog" {
  principal   = var.role_glue_rh_arn
  permissions = ["CREATE_TABLE", "ALTER", "DROP"]

  database {
    name = var.rh_db_name
  }

  depends_on = [aws_lakeformation_resource.datalake]
}
