variable "github_organization" {
  # populate the GitHub org for the event
  default = "tmx-gameday-aug16"
}

variable "participants" {
  type = map(any)
}

variable "event_name" {
  default = "gamify-cluster"
}

variable "event_hcp_project_id" {
  # populate the HCP project id
  default = "e49658b6-6c98-46c8-88a6-a7d10bcd3645"
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