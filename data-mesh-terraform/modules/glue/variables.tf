variable "bucket_name" {
  description = "Name of the S3 data lake bucket"
  type        = string
}

variable "project_name" {
  description = "Project name used for tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment used for tags"
  type        = string
}
