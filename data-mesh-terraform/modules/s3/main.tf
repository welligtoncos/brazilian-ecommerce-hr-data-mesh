resource "aws_s3_bucket" "datalake" {
  bucket = var.bucket_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

locals {
  bucket_prefixes = [
    "dominio=vendas/raw/order_items/",
    "dominio=vendas/raw/products/",
    "dominio=vendas/refined/",
    "dominio=rh/raw/",
    "dominio=rh/refined/",
    "scripts/",
    "athena-results/",
  ]
}

resource "aws_s3_object" "prefixes" {
  for_each = toset(local.bucket_prefixes)

  bucket  = aws_s3_bucket.datalake.id
  key     = each.value
  content = ""

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
