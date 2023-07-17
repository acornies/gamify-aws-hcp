---
slug: config-terraform-cloud
id: gstcs8trc9a2
type: challenge
title: Configure Terraform Cloud
teaser: Start your IaC journey the right way!
notes:
- type: text
  contents: |-
    This will be a super exciting initial statement!!!

    Please wait while we provision the AWS account and install Terraform.
tabs:
- title: Code Editor
  type: service
  hostname: vscode
  port: 8080
- title: AWS Console
  type: service
  hostname: cloud-client
  path: /
  port: 80
difficulty: basic
timelimit: 3600
---

👋 Getting Started
===============

Use the web-based VS Code IDE to your advantage and bring up the integrated terminal window with key shortcut:

**ctrl + `**

Next, connect to your VS Code workspace with a  Terraform Cloud workspace. In order to authenticate with Terraform Cloud, you will need an API team token. Your facilitator has supplied this token in your respective HCP Vault namespace. Please verify that you have access to:

- A Terraform Cloud organization and project (UI)
- An HCP Vault namespace (UI)

Once ready, create a new file named `main.tf` and configure the Terraform CLI remote backend:

```
terraform {
  cloud {
    organization = "<your-org>"

    workspaces {
      name = "<your-workspace-name>"
    }
  }
}
```
Replace the organization and workspace name values accordingly.

Now that we have the remote backend defined, copy & paste the `team_token` value in `kv/terraform` from your HCP Vault namespace and use it in the login prompt.

```
cd /app && terraform login
```

Assuming you're successfully authenticated, initialize the repository with:

```
terraform init
```

To complete this challenge, press **Check**.
