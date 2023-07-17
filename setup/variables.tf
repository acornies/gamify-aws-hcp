variable "participants" {
  type = map(any)
}

variable "event_name" {
  default = "gamify-cluster"
}

variable "event_tfc_organization" {
  # populate the TFC org name with .tfvars
}

variable "event_hcp_project_id" {
  # populate the HCP project id with .tfvars
}

variable "event_github_organization" {
  # populate the GitHub org name for the event with with .tfvars
}

variable "hcp_vault_region" {
  default = "us-east-2"
}

variable "hcp_vault_tier" {
  default = "dev"
}

variable "hcp_vault_cidr_block" {
  default = "172.25.16.0/20"
}

variable "hcp_vault_public_endpoint" {
  default = "true"
}