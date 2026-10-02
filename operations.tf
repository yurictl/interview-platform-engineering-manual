resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    id     = "report-cleanup"
    status = "Enabled"

    filter {
      prefix = "reports/"
    }

    expiration {
      days = 1
    }
  }
}

data "aws_secretsmanager_secret_version" "database" {
  secret_id = var.db_secret_arn
}

output "database_connection" {
  description = "Connection details for operational troubleshooting"
  sensitive   = true
  value = {
    host     = var.db_host
    port     = 5432
    database = "inventory"
    username = jsondecode(data.aws_secretsmanager_secret_version.database.secret_string)["username"]
    password = jsondecode(data.aws_secretsmanager_secret_version.database.secret_string)["password"]
  }
}
