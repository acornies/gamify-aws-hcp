# Gamify Facilitator Setup

## Step 0

## Step 1

Run the Terraform located in this directory.

## Postgres RDS database SQL

Create the scores table in the RDS instance:

```bash
psql -h terraform-20230808183755650300000002.chb8a6vdgolp.us-east-2.rds.amazonaws.com -U vaultadmin --dbname=leaderboard -f sql/001_create_scores.sql
```

## Participant event queue population

```bash
aws sqs send-message --queue-url https://sqs.us-east-2.amazonaws.com/395920473437/participant-events \
    --message-body "{\"leaderboard_queue\": \"https://sqs.us-east-2.amazonaws.com/395920473437/leaderboard-events\"}" \
    --delay-seconds 0
```

## Testing leaderboard scoring

```bash
aws sqs send-message --queue-url https://sqs.us-east-2.amazonaws.com/395920473437/leaderboard-events \
    --message-body "{\"function_name\": \"some-name\", \"function_arn\": \"the:arn\", \"account_id\": \"123456789\", \"points\": 10}" \
    --delay-seconds 0
```