# Gamify Facilitator Setup

## Step 0

## Step 1

Run the Terraform located in this directory.

## Postgres RDS database SQL

Set required env vars:

```bash
export PGHOST=$(terraform show -json | jq -r .values.outputs.aws_leaderboard_rds_instance_address.value)
export PGUSER=vaultadmin
export PGPASSWORD=$(terraform show -json | jq -r .values.outputs.aws_leaderboard_rds_instance_password.value)
export PGDATABASE=leaderboard
```

Connect using psql, create the scores table in the RDS instance:

```bash
psql -f sql/001_create_scores.sql
```

## Participant event queue population

```bash
ACCOUNT=$(aws sts get-caller-identity | jq -r .Account) && \
    aws sqs send-message --queue-url https://sqs.us-east-2.amazonaws.com/${ACCOUNT}/participant-events \
        --message-body "{\"leaderboard_queue\": \"https://sqs.us-east-2.amazonaws.com/${ACCOUNT}/leaderboard-events\"}" \
        --delay-seconds 0
```

## Testing leaderboard scoring

```bash
ACCOUNT=$(aws sts get-caller-identity | jq -r .Account) && \
    aws sqs send-message --queue-url https://sqs.us-east-2.amazonaws.com/${ACCOUNT}/leaderboard-events \
        --message-body "{\"function_name\": \"some-name\", \"function_arn\": \"the:arn\", \"account_id\": \"123456789\", \"points\": 10}" \
        --delay-seconds 0
```