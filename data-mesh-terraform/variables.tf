variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 data lake bucket"
  type        = string
  default     = "meu-datalake-mesh"
}

variable "project_name" {
  description = "Project name used for resource naming and tags"
  type        = string
  default     = "data-mesh"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
