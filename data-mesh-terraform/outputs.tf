output "bucket_name" {
  description = "Name of the data lake S3 bucket"
  value       = module.s3.bucket_name
}

output "bucket_arn" {
  description = "ARN of the data lake S3 bucket"
  value       = module.s3.bucket_arn
}

output "role_glue_vendas_arn" {
  description = "ARN of the Glue IAM role for the Vendas domain"
  value       = module.iam.role_glue_vendas_arn
}

output "role_glue_rh_arn" {
  description = "ARN of the Glue IAM role for the RH domain"
  value       = module.iam.role_glue_rh_arn
}

output "role_analytics_arn" {
  description = "ARN of the analytics IAM role for Athena consumption"
  value       = module.iam.role_analytics_arn
}

output "vendas_db_name" {
  description = "Name of the Glue Catalog database for the Vendas domain"
  value       = module.glue.vendas_db_name
}

output "rh_db_name" {
  description = "Name of the Glue Catalog database for the RH domain"
  value       = module.glue.rh_db_name
}

output "glue_job_vendas_name" {
  description = "Name of the Glue job for Vendas por categoria"
  value       = module.glue.glue_job_vendas_name
}

output "glue_job_rh_name" {
  description = "Name of the Glue job for RH funcionarios"
  value       = module.glue.glue_job_rh_name
}

output "crawler_vendas_name" {
  description = "Name of the Glue crawler for the Vendas domain"
  value       = module.glue.crawler_vendas_name
}

output "crawler_rh_name" {
  description = "Name of the Glue crawler for the RH domain"
  value       = module.glue.crawler_rh_name
}

output "athena_workgroup_name" {
  description = "Name of the Athena workgroup for analytics queries"
  value       = module.athena.workgroup_name
}

output "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena query results"
  value       = module.athena.athena_results_bucket
}

output "athena_results_bucket_arn" {
  description = "ARN of the S3 bucket for Athena query results"
  value       = module.athena.athena_results_bucket_arn
}
