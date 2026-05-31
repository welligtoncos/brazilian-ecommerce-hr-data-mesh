output "role_glue_vendas_arn" {
  description = "ARN of the Glue IAM role for the Vendas domain"
  value       = aws_iam_role.glue_vendas.arn
}

output "role_glue_rh_arn" {
  description = "ARN of the Glue IAM role for the RH domain"
  value       = aws_iam_role.glue_rh.arn
}

output "role_analytics_arn" {
  description = "ARN of the analytics IAM role"
  value       = aws_iam_role.analytics.arn
}
