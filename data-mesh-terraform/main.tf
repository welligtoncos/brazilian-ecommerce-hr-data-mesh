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

  bucket_name  = module.s3.bucket_name
  project_name = var.project_name
  environment  = var.environment

  depends_on = [module.s3]
}
