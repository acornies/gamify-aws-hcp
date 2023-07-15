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
      source = "hashicorp/vault"
    version = "3.18.0" }
  }
}

provider "tfe" {
  # Configuration options
}

resource "hcp_hvn" "event_cluster" {
  hvn_id         = "${var.event_name}-hvn"
  cloud_provider = "aws"
  region         = var.hcp_vault_region
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
  organization = var.github_organization
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