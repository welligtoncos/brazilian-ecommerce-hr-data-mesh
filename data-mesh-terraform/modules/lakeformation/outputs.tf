output "registered_bucket_arn" {
  description = "ARN of the S3 bucket registered in Lake Formation"
  value       = aws_lakeformation_resource.datalake.arn
}

output "data_lake_admin_arns" {
  description = "ARNs of the Lake Formation data lake administrators"
  value = [
    for admin in data.aws_lakeformation_data_lake_settings.current.admins :
    admin
  ]
}
