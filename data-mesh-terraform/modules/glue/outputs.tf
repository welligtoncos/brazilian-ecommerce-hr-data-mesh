output "vendas_db_name" {
  description = "Name of the Glue Catalog database for the Vendas domain"
  value       = aws_glue_catalog_database.vendas.name
}

output "rh_db_name" {
  description = "Name of the Glue Catalog database for the RH domain"
  value       = aws_glue_catalog_database.rh.name
}

output "vendas_db_arn" {
  description = "ARN of the Glue Catalog database for the Vendas domain"
  value       = aws_glue_catalog_database.vendas.arn
}

output "rh_db_arn" {
  description = "ARN of the Glue Catalog database for the RH domain"
  value       = aws_glue_catalog_database.rh.arn
}
