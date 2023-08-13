# AWS Resources
# ------------------------------

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

resource "aws_default_vpc" "default" {
}

resource "aws_sqs_queue" "participant" {
  name = "participant-events"
  tags = {
    Environment = var.event_name
  }
}

resource "aws_sqs_queue" "leaderboard" {
  name = "leaderboard-events"
  tags = {
    Environment = var.event_name
  }
}

# Grant anonymous access for this event
data "aws_iam_policy_document" "gamify_participant_access" {
  statement {
    sid    = "Participant_AnonymousAccess_ReceiveMessage"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["sqs:*"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "gamify_leaderboard_access" {
  statement {
    sid    = "Leaderboard_AnonymousAccess_ReceiveMessage"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["sqs:*"]
    resources = ["*"]
  }
}

# Set the SQS queue policy
resource "aws_sqs_queue_policy" "participant" {
  queue_url = aws_sqs_queue.participant.id
  policy    = data.aws_iam_policy_document.gamify_participant_access.json
}

resource "aws_sqs_queue_policy" "leaderboard" {
  queue_url = aws_sqs_queue.leaderboard.id
  policy    = data.aws_iam_policy_document.gamify_leaderboard_access.json
}

# Create image respoitories for the leaderboard funcs
resource "aws_ecr_repository" "leaderboard_http" {
  name = "gamify-func-leaderboard-http"
}

resource "aws_ecr_repository" "leaderboard_rec" {
  name = "gamify-func-leaderboard-rec"
}

resource "aws_lambda_function" "leaderboard_http" {
  function_name = "gamify-leaderboard-http"
  description   = "The faciliator http function for the leaderboard"
  role          = aws_iam_role.leaderboard_http.arn
  image_uri     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${aws_ecr_repository.leaderboard_http.name}:latest"
  package_type  = "Image"
  architectures = ["arm64"]

  environment {
    variables = {
      VAULT_ADDR           = hcp_vault_cluster.event_cluster.vault_public_endpoint_url,
      VAULT_NAMESPACE      = "admin/${vault_namespace.facilitator.path_fq}",
      VAULT_AUTH_ROLE      = aws_iam_role.leaderboard_http.name,
      VAULT_AUTH_PROVIDER  = "aws",
      VAULT_SECRET_PATH_DB = "database/creds/leaderboard-http",
      VAULT_SECRET_FILE_DB = "/tmp/vault_secret.json",
      # the database name needs to be appended to the endpoint
      DATABASE_ADDR = "${aws_db_instance.leaderboard.endpoint}/${aws_db_instance.leaderboard.db_name}"
    }
  }
}

resource "aws_lambda_function" "leaderboard_rec" {
  function_name = "gamify-leaderboard-rec"
  description   = "The faciliator record scores function for the leaderboard"
  role          = aws_iam_role.leaderboard_rec.arn
  image_uri     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${aws_ecr_repository.leaderboard_rec.name}:latest"
  package_type  = "Image"
  architectures = ["arm64"]

  environment {
    variables = {
      VAULT_ADDR           = hcp_vault_cluster.event_cluster.vault_public_endpoint_url,
      VAULT_NAMESPACE      = "admin/${vault_namespace.facilitator.path_fq}",
      VAULT_AUTH_ROLE      = aws_iam_role.leaderboard_rec.name,
      VAULT_AUTH_PROVIDER  = "aws",
      VAULT_SECRET_PATH_DB = "database/creds/leaderboard-rec",
      VAULT_SECRET_FILE_DB = "/tmp/vault_secret.json",
      # the database name needs to be appended to the endpoint
      DATABASE_ADDR = "${aws_db_instance.leaderboard.endpoint}/${aws_db_instance.leaderboard.db_name}"
    }
  }
}

# SQS Lambda event source mapping
resource "aws_lambda_event_source_mapping" "gamify" {
  event_source_arn = aws_sqs_queue.leaderboard.arn
  function_name    = aws_lambda_function.leaderboard_rec.arn
}

# The leaderboard http function needs an HTTP endpoint
resource "aws_lambda_function_url" "leaderboard_http" {
  function_name      = aws_lambda_function.leaderboard_http.function_name
  authorization_type = "NONE"
  cors {
    allow_methods = ["GET"]
    allow_origins = ["*"]
  }
}

resource "random_password" "password" {
  length  = 32
  special = false
}

# Create the RDS instance for the leaderboard
resource "aws_db_instance" "leaderboard" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "14.4"
  instance_class         = "db.t3.large"
  db_name                = "leaderboard"
  username               = "vaultadmin"
  password               = random_password.password.result
  vpc_security_group_ids = [aws_security_group.leaderboard_rds.id]
  skip_final_snapshot    = true
  publicly_accessible    = true
}

resource "aws_security_group" "leaderboard_rds" {
  name        = "leaderboard-rds-sg"
  description = "Leaderboard postgres traffic"
  vpc_id      = aws_default_vpc.default.id

  # Postgres traffic (not recommended for production)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "leaderboard" {
  name = "leaderboard-lambda-policy"
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

resource "aws_iam_user" "vault_client" {
  name = "vault-aws-auth-client"
}

resource "aws_iam_role" "leaderboard_http" {
  name = "leaderboard-http"
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

resource "aws_iam_role" "leaderboard_rec" {
  name = "leaderboard-rec"
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

# attach the leaderboard IAM policy to the vault client
resource "aws_iam_user_policy_attachment" "vault_client" {
  user       = aws_iam_user.vault_client.name
  policy_arn = aws_iam_policy.leaderboard.arn
}

# attach the leaderboard IAM policy to the leaderboard function roles
resource "aws_iam_role_policy_attachment" "leaderboard_http" {
  role       = aws_iam_role.leaderboard_http.name
  policy_arn = aws_iam_policy.leaderboard.arn
}

# attach managed policy for cloud watch
resource "aws_iam_role_policy_attachment" "leaderboard_http_logs" {
  role       = aws_iam_role.leaderboard_http.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "leaderboard_rec" {
  role       = aws_iam_role.leaderboard_rec.name
  policy_arn = aws_iam_policy.leaderboard.arn
}

# attach managed policy for cloud watch
resource "aws_iam_role_policy_attachment" "leaderboard_rec_logs" {
  role       = aws_iam_role.leaderboard_rec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Facilitator AWS-dependent Vault Resources
# ---------------------
# Add aws auth to the vault facilitator namespace
resource "vault_auth_backend" "aws" {
  namespace = vault_namespace.facilitator.path_fq
  type      = "aws"
  path      = "aws"
}

resource "vault_policy" "leaderboard" {
  namespace = vault_namespace.facilitator.path_fq
  name      = "leaderboard-http"
  policy    = <<EOT
path "database/creds/${vault_database_secret_backend_role.leaderboard_http.name}" {
    capabilities = ["read"]
}
EOT
}

resource "vault_policy" "leaderboard_rec" {
  namespace = vault_namespace.facilitator.path_fq
  name      = "leaderboard-rec"
  policy    = <<EOT
path "database/creds/${vault_database_secret_backend_role.leaderboard_rec.name}" {
    capabilities = ["read"]
}
EOT
}

resource "vault_database_secrets_mount" "leaderboard" {
  namespace = vault_namespace.facilitator.path_fq
  path      = "database"
  postgresql {
    name              = "postgres"
    username          = aws_db_instance.leaderboard.username
    password          = random_password.password.result
    connection_url    = "postgres://{{username}}:{{password}}@${aws_db_instance.leaderboard.endpoint}/${aws_db_instance.leaderboard.db_name}"
    verify_connection = true
    allowed_roles = [
      "leaderboard-*",
    ]
  }
}

# Alternative Vault CLI usage after IAM user creds are created
# Can also add these via the HCP Vault UI
# vault write auth/aws/config/client \
#   access_key= \
#   secret_key=
# resource "vault_aws_auth_backend_client" "gamify" {
#   backend    = vault_auth_backend.aws.path
#   access_key = ""
#   secret_key = ""
# }

# The leaderboard-http func only needs read access to the database
resource "vault_database_secret_backend_role" "leaderboard_http" {
  namespace = vault_namespace.facilitator.path_fq
  name      = aws_iam_role.leaderboard_http.name
  backend   = vault_database_secrets_mount.leaderboard.path
  db_name   = "postgres"
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ]
  default_ttl = 21600
  max_ttl     = 86400
}

# The leaderboard-rec func needs write access to the database
resource "vault_database_secret_backend_role" "leaderboard_rec" {
  namespace = vault_namespace.facilitator.path_fq
  name      = aws_iam_role.leaderboard_rec.name
  backend   = vault_database_secrets_mount.leaderboard.path
  db_name   = "postgres"
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",
    "GRANT INSERT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ]
  default_ttl = 21600
  max_ttl     = 86400
}

resource "vault_aws_auth_backend_role" "leaderboard_http" {
  backend                  = vault_auth_backend.aws.path
  namespace                = vault_namespace.facilitator.path_fq
  role                     = aws_iam_role.leaderboard_http.name
  auth_type                = "iam"
  bound_iam_principal_arns = ["${aws_iam_role.leaderboard_http.arn}"]
  token_ttl                = 21600
  token_policies           = ["default", "${vault_policy.leaderboard.name}"]
}

resource "vault_aws_auth_backend_role" "leaderboard_rec" {
  backend                  = vault_auth_backend.aws.path
  namespace                = vault_namespace.facilitator.path_fq
  role                     = aws_iam_role.leaderboard_rec.name
  auth_type                = "iam"
  bound_iam_principal_arns = ["${aws_iam_role.leaderboard_rec.arn}"]
  token_ttl                = 21600
  token_policies           = ["default", "${vault_policy.leaderboard_rec.name}"]
}

# Static hosting resources for frontend
# ------------------------------
# resource "aws_s3_bucket" "leaderboard" {
#   bucket = "leaderboard-${var.event_name}"
#   tags = {
#     Environment = var.event_name
#   }
# }

# resource "aws_s3_bucket_ownership_controls" "leaderboard" {
#   bucket = aws_s3_bucket.leaderboard.id
#   rule {
#     object_ownership = "BucketOwnerPreferred"
#   }
# }

# resource "aws_s3_bucket_public_access_block" "leaderboard" {
#   bucket = aws_s3_bucket.leaderboard.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# resource "aws_s3_bucket_acl" "leaderboard" {
#   depends_on = [
#     aws_s3_bucket_ownership_controls.leaderboard,
#     aws_s3_bucket_public_access_block.leaderboard,
#   ]
#   bucket = aws_s3_bucket.leaderboard.id
#   acl    = "public-read"
# }

# resource "aws_s3_object" "leaderboard_http" {
#   bucket = aws_s3_bucket.leaderboard.id
#   key    = "index.html"
#   source = "../src/leaderboard-frontend/index.html"
#   etag   = filemd5("../src/leaderboard-frontend/index.html")
# }

# resource "aws_s3_bucket_cors_configuration" "leaderboard_http" {
#   bucket = aws_s3_bucket.leaderboard.id

#   cors_rule {
#     allowed_methods = ["GET"]
#     allowed_origins = ["*"]
#   }
# }

# resource "aws_s3_bucket_website_configuration" "leaderboard" {
#   bucket = aws_s3_bucket.leaderboard.id

#   index_document {
#     suffix = "index.html"
#   }
# }