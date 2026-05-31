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

variable "vendas_db_name" {
  description = "Name of the Glue Catalog database for the Vendas domain"
  type        = string
}

variable "rh_db_name" {
  description = "Name of the Glue Catalog database for the RH domain"
  type        = string
}

variable "glue_script_vendas_id" {
  description = "S3 object ID of the Vendas Glue job script (dependency anchor)"
  type        = string
}

variable "glue_script_rh_id" {
  description = "S3 object ID of the RH Glue job script (dependency anchor)"
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
