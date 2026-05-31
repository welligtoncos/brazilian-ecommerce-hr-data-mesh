variable "project_name" {
  description = "Project name used for resource naming and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment used for resource naming and tags"
  type        = string
}

variable "role_analytics_arn" {
  description = "ARN of the analytics IAM role for Athena query results access"
  type        = string
}

variable "bucket_name" {
  description = "Name of the main data lake S3 bucket (reference for cross-module wiring)"
  type        = string
}
