module "s3" {
  source = "./modules/s3"

  bucket_name  = var.bucket_name
  project_name = var.project_name
  environment  = var.environment
}

module "iam" {
  source = "./modules/iam"

  bucket_name  = module.s3.bucket_name
  bucket_arn   = module.s3.bucket_arn
  project_name = var.project_name
  environment  = var.environment

  depends_on = [module.s3]
}

module "lakeformation" {
  source = "./modules/lakeformation"

  bucket_arn = module.s3.bucket_arn

  depends_on = [module.s3]
}

module "glue" {
  source = "./modules/glue"

  bucket_name           = module.s3.bucket_name
  role_glue_vendas_arn  = module.iam.role_glue_vendas_arn
  role_glue_rh_arn      = module.iam.role_glue_rh_arn
  vendas_db_name        = "vendas_db"
  rh_db_name            = "rh_db"
  glue_script_vendas_id = module.s3.glue_script_vendas_id
  glue_script_rh_id     = module.s3.glue_script_rh_id
  project_name          = var.project_name
  environment           = var.environment

  depends_on = [module.s3, module.iam]
}
