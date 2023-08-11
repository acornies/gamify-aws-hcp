provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "aws_default_vpc" "default" {
}

# Particiants may do this in the UI prior to running Docker build/push
resource "aws_ecr_repository" "gamify" {
  name = "gamify"
}

resource "aws_iam_user" "vault_client" {
  name = "vault-aws-auth-client"
}

# attach the leaderboard IAM policy to the vault client
resource "aws_iam_user_policy_attachment" "vault_client" {
  user       = aws_iam_user.vault_client.name
  policy_arn = aws_iam_policy.gamify.arn
}

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

# attach managed policy for cloud watch
resource "aws_iam_role_policy_attachment" "gamify_logs" {
  role       = aws_iam_role.gamify.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# attach managed policy for sqs receive/delete
resource "aws_iam_role_policy_attachment" "gamify_sqs" {
  role       = aws_iam_role.gamify.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
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
      DATABASE_ADDR        = "${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
    }
  }
}

# SQS Lambda event source mapping
resource "aws_lambda_event_source_mapping" "gamify" {
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

provider "vault" {

}

resource "vault_policy" "gamify" {
  name = "lambda-function"

  policy = <<EOT
path "database/creds/${vault_database_secret_backend_role.gamify.name}" {
    capabilities = ["read"]
}
EOT
}

resource "vault_database_secrets_mount" "gamify" {
  path = "database"

  postgresql {
    name              = "postgres"
    username          = aws_db_instance.main.username
    password          = random_password.password.result
    connection_url    = "postgres://{{username}}:{{password}}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
    verify_connection = true
    allowed_roles = [
      "lambda-*",
    ]
  }
}

resource "vault_database_secret_backend_role" "gamify" {
  name    = "lambda-function"
  backend = vault_database_secrets_mount.gamify.path
  db_name = "postgres"
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ]
}

resource "vault_auth_backend" "aws" {
  type = "aws"
  path = "aws"
}

# Alternative Vault CLI usage after IAM user creds are created
# vault write auth/aws/config/client \
#   access_key= \
#   secret_key=
# resource "vault_aws_auth_backend_client" "gamify" {
#   backend    = vault_auth_backend.aws.path
#   access_key = ""
#   secret_key = ""
# }

resource "vault_aws_auth_backend_role" "gamify" {
  backend                  = vault_auth_backend.aws.path
  role                     = aws_iam_role.gamify.name
  auth_type                = "iam"
  bound_iam_principal_arns = ["${aws_iam_role.gamify.arn}"]
  token_ttl                = 300
  token_policies           = ["default", "${vault_policy.gamify.name}"]
  # depends_on                      = ["vault_aws_auth_backend_client.gamify"]
}