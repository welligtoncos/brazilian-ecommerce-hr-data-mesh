data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "glue_vendas" {
  name = "${var.project_name}-role-glue-vendas-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "glue_vendas_service" {
  role       = aws_iam_role.glue_vendas.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_vendas" {
  name = "${var.project_name}-glue-vendas-s3-${var.environment}"
  role = aws_iam_role.glue_vendas.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListAndReadVendasAndScripts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/dominio=vendas",
          "${var.bucket_arn}/dominio=vendas/*",
          "${var.bucket_arn}/scripts",
          "${var.bucket_arn}/scripts/*"
        ]
      },
      {
        Sid    = "WriteVendasRefined"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.bucket_arn}/dominio=vendas/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

resource "aws_iam_role" "glue_rh" {
  name = "${var.project_name}-role-glue-rh-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "glue_rh_service" {
  role       = aws_iam_role.glue_rh.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_rh" {
  name = "${var.project_name}-glue-rh-s3-${var.environment}"
  role = aws_iam_role.glue_rh.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListAndReadRhAndScripts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/dominio=rh",
          "${var.bucket_arn}/dominio=rh/*",
          "${var.bucket_arn}/scripts",
          "${var.bucket_arn}/scripts/*"
        ]
      },
      {
        Sid    = "S3RHRefined"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.bucket_arn}/dominio=rh/*"
        ]
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

data "aws_iam_policy_document" "analytics_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }
  }
}

resource "aws_iam_role" "analytics" {
  name               = "${var.project_name}-role-analytics-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.analytics_trust.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "analytics" {
  name = "${var.project_name}-analytics-${var.environment}"
  role = aws_iam_role.analytics.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AthenaQueryExecution"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution"
        ]
        Resource = "*"
      },
      {
        Sid    = "AthenaResultsBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-athena-results-${var.environment}",
          "arn:aws:s3:::${var.project_name}-athena-results-${var.environment}/*"
        ]
      },
      {
        Sid    = "GlueCatalogRead"
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        Sid    = "LakeFormationDataAccess"
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess",
          "lakeformation:GetMetadataAccess"
        ]
        Resource = "*"
      }
    ]
  })
}
