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
    resources = [aws_sqs_queue.participant.arn]
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
    resources = [aws_sqs_queue.leaderboard.arn]
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
  image_uri     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${aws_ecr_repository.leaderboard_http.name}:v0.1.0"
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

# The leaderboard http function needs an HTTP endpoint
resource "aws_lambda_function_url" "leaderboard_http" {
  function_name      = aws_lambda_function.leaderboard_http.function_name
  authorization_type = "NONE"
}

resource "random_password" "password" {
  length  = 32
  special = false
}

resource "aws_db_instance" "leaderboard" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "14.4"
  instance_class         = "db.t3.micro"
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

  # Postgres traffic
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

resource "aws_iam_role_policy_attachment" "leaderboard_http" {
  role       = aws_iam_role.leaderboard_http.name
  policy_arn = aws_iam_policy.leaderboard.arn
}