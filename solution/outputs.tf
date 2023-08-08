output "rds_instance_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "rds_instance_address" {
  value = aws_db_instance.main.address
}

output "rds_instance_username" {
  value     = aws_db_instance.main.username
  sensitive = true
}

output "rds_instance_password" {
  value     = random_password.password.result
  sensitive = true
}

output "aws_iam_lambda_role_arn" {
  value = aws_iam_role.gamify.arn
}