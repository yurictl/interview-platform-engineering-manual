terraform {
  required_version = ">= 1.5, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

variable "source_bucket" {
  type = string
}

variable "report_bucket" {
  type = string
}

variable "image_uri" {
  description = "Existing ECR image URI pinned by digest"
  type        = string
}

resource "aws_s3_bucket" "reports" {
  bucket        = var.report_bucket
  force_destroy = true
}

resource "aws_iam_role" "inventory" {
  name = "interview-s3-inventory"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "inventory" {
  role = aws_iam_role.inventory.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.source_bucket}"
        Condition = {
          StringLike = { "s3:prefix" = "exports/*" }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = aws_s3_bucket.reports.arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.db_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.inventory.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "inventory" {
  function_name                  = "interview-s3-inventory"
  role                           = aws_iam_role.inventory.arn
  package_type                   = "Image"
  image_uri                      = var.image_uri
  architectures                  = ["x86_64"]
  timeout                        = 30
  memory_size                    = 256
  reserved_concurrent_executions = 0

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.inventory.id]
  }

  environment {
    variables = {
      SOURCE_BUCKET = var.source_bucket
      SOURCE_PREFIX = "exports/"
      REPORT_BUCKET = aws_s3_bucket.reports.id
      DB_HOST       = var.db_host
      DB_PORT       = "3306"
      DB_SECRET_ARN = var.db_secret_arn
    }
  }

  lifecycle {
    ignore_changes = [image_uri, environment]
  }

  depends_on = [
    aws_iam_role_policy.inventory,
    aws_iam_role_policy_attachment.logs,
  ]
}
