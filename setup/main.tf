terraform {
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.46.0"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "0.66.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.18.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "5.10.0"
    }
  }
}

provider "tfe" {
}

resource "hcp_hvn" "event_cluster" {
  hvn_id         = "${var.event_name}-hvn"
  cloud_provider = "aws"
  region         = var.region
  cidr_block     = var.hcp_vault_cidr_block
}

provider "hcp" {
  project_id = var.event_hcp_project_id
}

resource "hcp_vault_cluster" "event_cluster" {
  cluster_id      = var.event_name
  hvn_id          = hcp_hvn.event_cluster.hvn_id
  tier            = var.hcp_vault_tier
  public_endpoint = var.hcp_vault_public_endpoint
  lifecycle {
    prevent_destroy = true
  }
}

resource "hcp_vault_cluster_admin_token" "event_cluster" {
  cluster_id = hcp_vault_cluster.event_cluster.cluster_id
}

provider "vault" {
  namespace = "admin"
  address   = hcp_vault_cluster.event_cluster.vault_public_endpoint_url
  token     = hcp_vault_cluster_admin_token.event_cluster.token
}

# Create namespace for the facilitator
resource "vault_namespace" "facilitator" {
  path = "${var.event_name}-facilitator"
}

# Create the namespaces from the map defined in variables.tf
resource "vault_namespace" "participants" {
  for_each = var.participants
  path     = each.key
}

# Create a "sudo" policy in each namespace
resource "vault_policy" "participants" {
  for_each  = var.participants
  namespace = vault_namespace.participants[each.key].path_fq
  name      = "admin"
  policy    = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

# Create a GitHub auth backend in each namespace under path "github"
resource "vault_github_auth_backend" "participants" {
  for_each     = var.participants
  namespace    = vault_namespace.participants[each.key].path_fq
  organization = var.event_github_organization
}

# Use the "team" property in the participants variable to assign the appropriate GitHub
# team for the GitHub auth backend for each namespace, assign it the "dev" policy
resource "vault_github_team" "participants" {
  for_each  = var.participants
  namespace = vault_namespace.participants[each.key].path_fq
  backend   = vault_github_auth_backend.participants[each.key].id
  team      = each.value.team
  policies  = ["admin"]
}

# Create the secrets v2 engine in each particpant namespace under path "kv"
resource "vault_mount" "participants" {
  for_each  = var.participants
  namespace = vault_namespace.participants[each.key].path_fq
  path      = "kv"
  type      = "kv"
  options = {
    version = "2"
  }
}

data "tfe_organization" "event_org" {
  name = var.event_tfc_organization
}

resource "tfe_project" "event_project" {
  organization = data.tfe_organization.event_org.name
  name         = var.event_name
}

resource "tfe_team" "participants" {
  for_each     = var.participants
  organization = data.tfe_organization.event_org.name
  name         = each.value.team
  visibility   = "secret"
  organization_access {
    manage_vcs_settings = true
    manage_modules      = true
    manage_run_tasks    = true
  }
}

resource "tfe_workspace" "challenges" {
  for_each     = var.participants
  name         = each.key
  organization = data.tfe_organization.event_org.name
  tag_names    = ["${var.event_name}"]
  project_id   = tfe_project.event_project.id
}

# Add team admin access to workspace
resource "tfe_team_access" "challenges" {
  for_each     = var.participants
  access       = "admin"
  team_id      = tfe_team.participants[each.key].id
  workspace_id = tfe_workspace.challenges[each.key].id
}

# Add the team caption email to the TFC organization
# resource "tfe_organization_membership" "participants" {
#   for_each     = var.participants
#   organization = data.tfe_organization.event_org.name
#   email        = each.value.email
# }

# Create a TFC team token per team
resource "tfe_team_token" "participants" {
  for_each = var.participants
  team_id  = tfe_team.participants[each.key].id
}

# Save TFC team token in Vault
resource "vault_kv_secret_v2" "tfc_team_token" {
  for_each            = var.participants
  namespace           = vault_namespace.participants[each.key].path_fq
  mount               = vault_mount.participants[each.key].path
  name                = "terraform"
  cas                 = 1
  delete_all_versions = true
  data_json = jsonencode(
    {
      team_token = tfe_team_token.participants[each.key].token,
    }
  )
}

# Add HCP Vault endpoint as a TF workspace variable
resource "tfe_variable" "hcp_vault_endpoint" {
  for_each     = var.participants
  key          = "VAULT_ADDR"
  value        = hcp_vault_cluster.event_cluster.vault_public_endpoint_url
  category     = "env"
  workspace_id = tfe_workspace.challenges[each.key].id
}

# Add HCP Vault namespace as a TF workspace variable
resource "tfe_variable" "hcp_vault_namespace" {
  for_each     = var.participants
  key          = "VAULT_NAMESPACE"
  value        = each.key
  category     = "env"
  workspace_id = tfe_workspace.challenges[each.key].id
}

# Facilitator Vault Resources
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
# vault write auth/aws/config/client \
#   access_key= \
#   secret_key=
# resource "vault_aws_auth_backend_client" "gamify" {
#   backend    = vault_auth_backend.aws.path
#   access_key = ""
#   secret_key = ""
# }

resource "vault_database_secret_backend_role" "leaderboard_http" {
  namespace = vault_namespace.facilitator.path_fq
  name      = aws_iam_role.leaderboard_http.name
  backend   = vault_database_secrets_mount.leaderboard.path
  db_name   = "postgres"
  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ]
}

resource "vault_aws_auth_backend_role" "leaderboard_http" {
  backend                  = vault_auth_backend.aws.path
  namespace                = vault_namespace.facilitator.path_fq
  role                     = aws_iam_role.leaderboard_http.name
  auth_type                = "iam"
  bound_iam_principal_arns = ["${aws_iam_role.leaderboard_http.arn}"]
  token_ttl                = 300
  token_policies           = ["default", "${vault_policy.leaderboard.name}"]
}