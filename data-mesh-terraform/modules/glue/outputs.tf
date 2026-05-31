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

output "glue_job_vendas_name" {
  description = "Name of the Glue job for Vendas por categoria"
  value       = aws_glue_job.vendas_por_categoria.name
}

output "glue_job_rh_name" {
  description = "Name of the Glue job for RH funcionarios"
  value       = aws_glue_job.rh_funcionarios.name
}

output "crawler_vendas_name" {
  description = "Name of the Glue crawler for the Vendas domain"
  value       = aws_glue_crawler.vendas.name
}

output "crawler_rh_name" {
  description = "Name of the Glue crawler for the RH domain"
  value       = aws_glue_crawler.rh.name
}
