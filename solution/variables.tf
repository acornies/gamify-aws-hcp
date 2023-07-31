variable "aws_region" {
  default = "us-east-2"
}

# All resources will be tagged with this
variable "environment_name" {
  default = "gamify-demo"
}

variable "hcp_vault_endpoint" {
  default = "https://gamify-cluster-public-vault-93cf54a5.600f47fd.z1.hashicorp.cloud:8200"
}

variable "hcp_vault_namespace" {
  default = "admin/super-awesome-team"
}

# DB instance size
variable "db_instance_type" {
  default = "db.t3.micro"
}

# SQS ARN provided by the facilitator
variable "sqs_arn" {
  default = "arn:aws:sqs:us-east-2:395920473437:gamify"
}