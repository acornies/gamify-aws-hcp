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