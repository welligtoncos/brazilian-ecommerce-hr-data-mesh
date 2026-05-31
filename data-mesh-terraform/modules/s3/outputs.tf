output "bucket_name" {
  description = "Name of the data lake S3 bucket"
  value       = aws_s3_bucket.datalake.id
}

output "bucket_arn" {
  description = "ARN of the data lake S3 bucket"
  value       = aws_s3_bucket.datalake.arn
}

output "bucket_id" {
  description = "ID of the data lake S3 bucket (for dependency ordering)"
  value       = aws_s3_bucket.datalake.id
}

output "glue_script_vendas_id" {
  description = "S3 object ID of the Vendas Glue job script"
  value       = aws_s3_object.job_vendas_por_categoria.id
}

output "glue_script_rh_id" {
  description = "S3 object ID of the RH Glue job script"
  value       = aws_s3_object.job_rh_funcionarios.id
}
