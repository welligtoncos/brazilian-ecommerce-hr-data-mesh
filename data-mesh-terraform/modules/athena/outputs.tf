output "workgroup_name" {
  description = "Name of the Athena workgroup for analytics queries"
  value       = aws_athena_workgroup.analytics.name
}

output "athena_results_bucket" {
  description = "Name of the S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.id
}

output "athena_results_bucket_arn" {
  description = "ARN of the S3 bucket for Athena query results"
  value       = aws_s3_bucket.athena_results.arn
}

output "results_location" {
  description = "S3 location for Athena query results"
  value       = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
}
