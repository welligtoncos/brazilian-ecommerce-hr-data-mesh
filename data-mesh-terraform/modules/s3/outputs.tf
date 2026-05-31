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
