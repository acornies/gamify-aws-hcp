# Gamify AWS and HCP

A gamified workshop for accounts using AWS and HCP services. Use this track to generate excitement for an account with relevant architecture.

## Challenges

- 🐳 Build and push a Docker container for the X application (source code provided)
- 📝 Use Terraform to provision an AWS ECS container and an AWS RDS instance for the X application
- 🚀 Use Terraform to provision an HCP Vault cluster or HCP Vault Secrets instance
- ☁️ Hook up your Terraform code/workspace to Terraform Cloud
- 🔒 Update the X application running in ECS by integrating HCP Vault to secure the database connection

## Prerequisites

This track is designed to be used in a full day event where participants compete by completing the challenges in a 3 hour time limit. The following is a list of resources needed before the start of the event:

### Facilitators SE/SAs

- Review the [setup](./setup/) folder to execute the necessary Terraform
- An HCP account (@hashicorp.com email address)
- A Terraform Cloud Plus/Business org (#team-se-trial-rqsts Slack channel)

### Participants

- Internet access, web browser
- A GitHub account
- Terraform Cloud org and workspace
  - Team token
- HCP Vault endpoint
  - Namespace (team or participant name)
  - Auth method for HCP Vault namespace

Participants will access the Instruqt platform via a web browser. Personal GitHub accounts are needed to configure a VCS connection to Terraform Cloud.


