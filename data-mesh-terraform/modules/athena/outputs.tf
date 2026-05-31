output "workgroup_name" {
  description = "Name of the Athena workgroup for analytics queries"
  value       = aws_athena_workgroup.analytics.name
}

output "results_location" {
  description = "S3 location for Athena query results"
  value       = "s3://${var.bucket_name}/athena-results/"
}
