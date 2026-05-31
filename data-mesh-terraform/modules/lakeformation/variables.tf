variable "bucket_arn" {
  description = "ARN of the S3 data lake bucket to register in Lake Formation"
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 data lake bucket"
  type        = string
}

variable "role_glue_vendas_arn" {
  description = "ARN of the Glue IAM role for the Vendas domain"
  type        = string
}

variable "role_glue_rh_arn" {
  description = "ARN of the Glue IAM role for the RH domain"
  type        = string
}

variable "role_analytics_arn" {
  description = "ARN of the analytics IAM role for Athena consumption"
  type        = string
}

variable "vendas_db_name" {
  description = "Name of the Glue Catalog database for the Vendas domain"
  type        = string
}

variable "rh_db_name" {
  description = "Name of the Glue Catalog database for the RH domain"
  type        = string
}
