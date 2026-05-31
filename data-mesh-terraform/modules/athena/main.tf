# Athena workgroup — wired in Sprint 2 when query workloads are configured.
resource "aws_athena_workgroup" "analytics" {
  name = "${var.project_name}-analytics-${var.environment}"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.bucket_name}/athena-results/"
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
