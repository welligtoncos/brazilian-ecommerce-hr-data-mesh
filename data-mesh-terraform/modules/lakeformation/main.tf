data "aws_caller_identity" "current" {}

# Settings are read-only here because AWSLakeFormationDataAdmin explicitly denies
# lakeformation:PutDataLakeSettings. Initial admin setup must be done once by
# account root (Console or a principal without that deny).
data "aws_lakeformation_data_lake_settings" "current" {}

resource "aws_lakeformation_resource" "datalake" {
  arn                     = var.bucket_arn
  use_service_linked_role = true
}
