output "hcp_vault_endpoint" {
  value = hcp_vault_cluster.event_cluster.vault_public_endpoint_url
}

output "hcp_vault_region" {
  value = hcp_vault_cluster.event_cluster.region
}

output "hcp_vault_admin_token" {
  sensitive = true
  value     = hcp_vault_cluster_admin_token.event_cluster.token
}

output "aws_gamify_sqs_arn" {
  value = aws_sqs_queue.gamify.arn
}

output "aws_gamify_sqs_url" {
  value = aws_sqs_queue.gamify.url
}