resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-athena-results-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "athena-results"
  }
}

resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-query-results"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_lakeformation_resource" "athena_results" {
  arn      = aws_s3_bucket.athena_results.arn
  role_arn = var.role_analytics_arn
}

resource "aws_athena_workgroup" "analytics" {
  name  = "wg-analytics"
  state = "ENABLED"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_lakeformation_resource.athena_results]
}
