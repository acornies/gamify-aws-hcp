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
difficulty: ""
---

👋 Getting Started
===============

Use the web-based VS Code IDE to your advantage and bring up the integrated terminal window with key shortcut:

**ctrl + `**

## HCP Vault Access

Let's hook up the Vault CLI with your provided HCP Vault endpoint and namespace:
```
export VAULT_ADDR=<hcp-vault-endpoint-here>
export VAULT_NAMESPACE=admin/<your-namespace-here>
```

Execute this for the upcoming challenges:
```
# Save to bash profile
echo "export VAULT_ADDR=${VAULT_ADDR}" >> /root/.bashrc
echo "export VAULT_NAMESPACE=${VAULT_NAMESPACE}" >> /root/.bashrc
```

Login to your HCP Vault namespace using a personal GitHub API token:
```
vault login -method github
```

You should now be able to list your kv secrets using this command:
```
vault kv get -format=json kv/terraform
```

## Terraform Cloud Access

Next, connect to your VS Code workspace with a  Terraform Cloud workspace. In order to authenticate with Terraform Cloud, you will need an API team token. Your facilitator has supplied this token in your respective HCP Vault namespace. Please verify that you have access to:

- A Terraform Cloud organization and project (UI)
- An HCP Vault namespace (UI)

Once ready, open the file `terraform.tf` and replace the organization and workspace name values accordingly.

Now that we have the remote backend defined, copy & paste the Terraform team token value and use it in the login prompt.

```
echo $(vault kv get -format=json kv/terraform | jq -r .data.data.team_token)

terraform login
```

Assuming you're successfully authenticated, initialize the repository with:

```
cd /app && terraform init
```

Press **Check** to move on to the next challenge.
