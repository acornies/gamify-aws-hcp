provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_default_vpc" "default" {
}

# Particiants may do this in the UI prior to running Docker build/push
# resource "aws_ecr_repository" "gamify" {
#   name = "gamify"
# }

resource "aws_iam_policy" "gamify" {
  name = "gamify-lambda-function-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:DescribeInstances",
          "iam:GetInstanceProfile",
          "iam:GetUser",
          "iam:ListRoles",
          "iam:GetRole"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "gamify" {
  name = "gamify-demo-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "gamify" {
  role       = aws_iam_role.gamify.name
  policy_arn = aws_iam_policy.gamify.arn
}

resource "aws_lambda_function" "function" {
  function_name = "${var.environment_name}-function"
  description   = "Demo Vault AWS Lambda extension in container"
  role          = aws_iam_role.gamify.arn
  image_uri     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/gamify:latest"
  package_type  = "Image"

  environment {
    variables = {
      VAULT_ADDR           = var.hcp_vault_endpoint,
      VAULT_NAMESPACE      = var.hcp_vault_namespace,
      VAULT_AUTH_ROLE      = aws_iam_role.gamify.name,
      VAULT_AUTH_PROVIDER  = "aws",
      VAULT_SECRET_PATH_DB = "database/creds/lambda-function",
      VAULT_SECRET_FILE_DB = "/tmp/vault_secret.json",
      DATABASE_URL         = aws_db_instance.main.address
    }
  }
}

resource "aws_lambda_function_url" "gamify" {
  function_name      = aws_lambda_function.function.function_name
  authorization_type = "NONE"
}

# SQS Lambda event source mapping
resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn = var.sqs_arn
  function_name    = aws_lambda_function.function.arn
}

resource "random_password" "password" {
  length  = 32
  special = false
}

resource "aws_db_instance" "main" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "14.4"
  instance_class         = var.db_instance_type
  db_name                = "lambdadb"
  username               = "vaultadmin"
  password               = random_password.password.result
  vpc_security_group_ids = [aws_security_group.rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = true
}

resource "aws_security_group" "rds" {
  name        = "${var.environment_name}-rds-sg"
  description = "Postgres traffic"
  vpc_id      = aws_default_vpc.default.id

  tags = {
    Name = var.environment_name
  }

  # Postgres traffic
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}