# Gamify AWS and HCP

A gamified workshop for accounts using AWS and HCP services. Use this track to generate excitement for an account with relevant architecture.

## Challenges

- ☁️ Hook up your Terraform code/workspace to Terraform Cloud (team token provided)
- 🐳 Build and push a Docker container for the Lambda function to AWS ECR (source code provided)
- 📝 Use Terraform to provision an AWS Lambda function, an AWS RDS instance to receive messages from SQS and store the data
- 🚀 Use Terraform to configure your HCP Vault namespace for the Lambda Vault extension (namespace provided)
- 🔒 Secure the Lambda function's database connection using HashiCorp Vault

## Prerequisites

This track is designed to be used in a full day event where participants compete by completing the challenges in a 3-4 hour time limit. The following is a list of resources needed before the start of the event:

### Facilitators SE/SAs

- Review the [setup](./setup/) folder to execute the necessary Terraform
- Review the [solution](./solution/) folder to see a example code solution to the challenge
- An HCP account (@hashicorp.com email address)
- A Terraform Cloud Plus/Business org (#team-se-trial-rqsts Slack channel)
- A new GitHub organization for the event
- An AWS account (provisioned by [Doormat](https://doormat.hashicorp.services/))

### Event preparation

Example SQS event publishing:

```bash
aws sqs send-message --queue-url https://sqs.us-east-2.amazonaws.com/395920473437/gamify --message-body "This is a Dreamcast 5 console registration" \
  --delay-seconds 1 --message-attributes file://./src/json/send-message.json
```

### Participants

- Internet access, web browser
- A GitHub account
- Terraform Cloud org and workspace
  - Team token
- HCP Vault endpoint
  - Namespace (team or participant name)
- An AWS account vended by AWS Workshop Studio

Personal GitHub accounts are needed to add participants to an event organization team. It is recommended to create a new GitHub org specific to the Gamify event.

### Contributors

See the [src](./src/) directory for source code of the following components:

- The leaderboard service
- Example SQS message to populate the AWS SQS queue