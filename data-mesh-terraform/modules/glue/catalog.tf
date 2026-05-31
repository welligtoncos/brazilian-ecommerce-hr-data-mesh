resource "aws_glue_catalog_database" "vendas" {
  name        = "vendas_db"
  description = "Glue Catalog database for the Vendas domain (Olist e-commerce dataset)"

  location_uri = "s3://${var.bucket_name}/dominio=vendas/"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_glue_catalog_database" "rh" {
  name        = "rh_db"
  description = "Glue Catalog database for the RH domain (IBM HR Attrition dataset)"

  location_uri = "s3://${var.bucket_name}/dominio=rh/"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
